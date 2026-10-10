"""
mocha_wasm.py - build a Mocha program as a WebAssembly (wasm32-wasi) module.

Standalone for now:
  python mocha_wasm.py cape_demo.ll --lib lib\\mocha-math.ll --lib lib\\mocha-meteoro.ll --export cape_demo
Later, the compiler can import compile_wasm() to support `mocha --wasm`.
Needs the C runtime to contain the MOCHA_WASM guards and the mocha_malloc64 shim.
"""
import argparse, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _patch_ir(src, dst):
    """wasm32's malloc takes a 32-bit size, but the IR declares malloc(i64). Route it through a shim."""
    with open(src, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"@malloc\b", "@mocha_malloc64", text)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def compile_wasm(program_ll, output_wasm, exports, lib_lls=(), zig_path=None,
                 zig_lib_dir=None, runtime_c=None, build_dir=None):
    zig_path    = zig_path    or os.path.join(HERE, "zig.exe" if os.name == "nt" else "zig")
    zig_lib_dir = zig_lib_dir or os.path.join(HERE, "zig-lib")
    runtime_c   = runtime_c   or os.path.join(HERE, "mocha_runtime.c")
    build_dir   = build_dir   or os.path.join(HERE, "wasm_build")
    os.makedirs(build_dir, exist_ok=True)

    env = os.environ.copy()
    env["ZIG_LIB_DIR"] = zig_lib_dir
    cc = [zig_path, "cc", "-target", "wasm32-wasi", "-O2"]
    warnings = []

    def step(cmd, what):
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", env=env)
        if r.returncode != 0:
            print(f"  ❌ {what} failed:\n{r.stderr}")
            return False
        warnings.extend(l.strip() for l in r.stderr.splitlines()
                        if "function signature mismatch" in l)
        return True

    # 1. the C runtime (cached; rebuilt only when mocha_runtime.c changes)
    rt_obj = os.path.join(build_dir, "rt_wasm.o")
    if not os.path.exists(rt_obj) or os.path.getmtime(runtime_c) > os.path.getmtime(rt_obj):
        print("  🔧 Building the wasm runtime (first time, or the runtime changed)...")
        if not step(cc + ["-c", runtime_c, "-o", rt_obj], "runtime compile"):
            return False
    else:
        print("  ⚡ wasm runtime cached")

    # 2. libraries + the program: patch the IR, then compile each to a wasm object
    objs = []
    for ll in list(lib_lls) + [program_ll]:
        name = os.path.splitext(os.path.basename(ll))[0]
        patched = os.path.join(build_dir, name + ".ll")
        obj = os.path.join(build_dir, name + ".o")
        _patch_ir(ll, patched)
        if not step(cc + ["-c", patched, "-o", obj], f"compile {name}"):
            return False
        objs.append(obj)

    # 3. link as a reactor module (a library the browser calls into, not a program with main)
    link = [zig_path, "cc", "-target", "wasm32-wasi", "-mexec-model=reactor"]
    link += [f"-Wl,--export={e}" for e in exports]
    link += objs + [rt_obj, "-o", output_wasm]
    if not step(link, "link"):
        return False

    for w in sorted(set(warnings)):
        print("  ⚠️ ", w)
    print(f"  ✅ Wrote {output_wasm} ({os.path.getsize(output_wasm) // 1024} KB)")
    return True


def main():
    ap = argparse.ArgumentParser(description="Build a Mocha program as WebAssembly")
    ap.add_argument("program_ll")
    ap.add_argument("--lib", action="append", default=[], help="library .ll file (repeat)")
    ap.add_argument("--export", action="append", required=True, help="function to expose to JS (repeat)")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()
    out = a.output or os.path.splitext(a.program_ll)[0] + ".wasm"
    sys.exit(0 if compile_wasm(a.program_ll, out, a.export, a.lib) else 1)


if __name__ == "__main__":
    main()