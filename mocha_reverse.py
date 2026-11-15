# mocha_reverse.py  --  mocha reverse <file.ll> [-o out.mch] [--force] [--debug]
import sys
import os


def reverse(ll_text):
    """LLVM IR text (a .ll file written by the Mocha compiler) -> Mocha source text."""
    from mocha_writer import write_module
    return write_module(ll_text).rstrip("\n") + "\n"


def fail(msg):
    print(f"mocha reverse: error: {msg}", file=sys.stderr)
    return 1


def main(argv):
    argv = [a for a in argv if a]              # the launcher passes unused slots as empty strings
    debug, force = "--debug" in argv, "--force" in argv
    out, rest, i = None, [], 0
    while i < len(argv):
        a = argv[i]
        if a == "-o":
            if i + 1 >= len(argv):
                return fail("-o needs a file name")
            out = argv[i + 1]
            i += 2
            continue
        if not a.startswith("--"):
            rest.append(a)
        i += 1
    if len(rest) != 1:
        return fail("usage: mocha reverse <file.ll> [-o out.mch] [--force] [--debug]")
    src = rest[0]
    if not src.lower().endswith(".ll"):
        return fail(f"'{src}' is not a .ll file (mocha reverse reads the LLVM IR the compiler writes next to your program)")
    if not os.path.isfile(src):
        return fail(f"cannot find '{src}'")
    if out is None:
        out = os.path.splitext(src)[0] + ".reversed.mch"
    if os.path.exists(out) and not force:
        return fail(f"'{out}' already exists (use -o <name> to pick another file, or --force to overwrite it)")
    import glob
    lib = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib")
    if glob.glob(os.path.join(lib, "mocha-*.mch")) and not glob.glob(os.path.join(lib, "mocha-*.ll")):
        print("mocha reverse: warning: the libraries are not built yet (no lib\\mocha-*.ll), so imports of library "
              "functions will be missing from the output (run: mocha libs)", file=sys.stderr)
    try:
        with open(src, encoding="utf-8") as f:
            text = f.read()
    except (OSError, UnicodeDecodeError) as e:
        return fail(f"cannot read '{src}': {e}")
    try:
        mch = reverse(text)
    except Exception as e:
        if debug:
            raise
        return fail(f"could not reverse '{src}' ({type(e).__name__}: {e}). "
                    f"This usually means the file uses something the decompiler does not support yet. Run with --debug for the full trace.")
    with open(out, "w", encoding="utf-8", newline="\n") as f:      # the same bytes on every OS (what the decompiler was tested with)
        f.write(mch)
    print(f"mocha reverse: wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))