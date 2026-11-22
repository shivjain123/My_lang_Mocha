# mocha_build_tables.py  --  maintainer tool: rebuild every json table the decompiler reads.
#   python mocha_build_tables.py
# Run it after changing a library or the runtime, then commit the json files.
import os, re, sys, json, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = dict(os.environ, PYTHONIOENCODING="utf-8")


def child(script, *args):
    return subprocess.run([sys.executable, os.path.join(HERE, script), *args], capture_output=True,
                          text=True, encoding="utf-8", errors="replace", cwd=HERE, env=ENV)


def build_prelude():
    """Every declare the compiler writes into an empty program: the runtime plus the always-loaded libs."""
    with tempfile.TemporaryDirectory() as d:
        src, out = os.path.join(d, "empty.mch"), os.path.join(d, "empty")
        with open(src, "w", encoding="utf-8") as f:
            f.write("function main(didLoad) -> null {\n};\n")
        r = child("mocha_compile.py", src, out)
        if not os.path.exists(out + ".ll"):           # clang may fail after the .ll is written; the .ll is all we need
            sys.exit("mocha_build_tables: the compiler wrote no .ll for an empty program:\n" + r.stdout + r.stderr)
        with open(out + ".ll", encoding="utf-8") as f:
            text = f.read()
    return sorted(set(re.findall(r'^declare .*@([\w.$]+)\(', text, re.M)))


def main():
    path = os.path.join(HERE, "runtime_prelude.json")
    old = set(json.load(open(path, encoding="utf-8"))) if os.path.exists(path) else set()
    names = build_prelude()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(names, f)
    if old and old != set(names):
        print(f"runtime_prelude.json CHANGED: {len(set(names) - old)} added, {len(old - set(names))} removed")
        print("  added:", sorted(set(names) - old)[:15])
        print("  removed:", sorted(old - set(names))[:15])
    else:
        print(f"runtime_prelude.json: {len(names)} symbols" + (" (unchanged)" if old else " (new)"))
    for script, args in (("build_native_aliases.py", ()), ("build_lib_signatures.py", ("--no-validate",))):
        r = child(script, *args)
        if r.returncode != 0:
            sys.exit(f"mocha_build_tables: {script} failed:\n{r.stdout}{r.stderr}")
        print(f"{script}: ok")
    print("done. Commit: native_aliases.json native_rets.json lib_sigs.json lib_defaults.json runtime_prelude.json")


if __name__ == "__main__":
    main()