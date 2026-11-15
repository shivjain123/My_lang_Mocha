# finish_test.py  (run from the PROJECT folder)
#   python finish_test.py 20            first 20 decompiled files
#   python finish_test.py name1 name2   just these
import sys, os, glob, subprocess, difflib, re


def lines(path):
    out = []
    for l in open(path, encoding="utf-8"):
        if not l.strip() or l.startswith("declare") or l.lstrip().startswith(";"):
            continue
        l = re.sub(r'(@mocha_stack_update_line\(i32) \d+\)', r'\1 N)', l.rstrip())
        l = re.sub(r'(@mocha_stack_push\(.*, i32) \d+\)', r'\1 N)', l)
        out.append(l)
        res, fn = [], []

    def flush():
        txt = "\n".join(fn)
        dead = {m.group(1) for m in re.finditer(r'^\s*(%\w+) = add i8 0, [01]\s*$', txt, re.M)
                if len(re.findall(re.escape(m.group(1)) + r'(?![\w.])', txt)) == 1}
        kept = [x for x in fn if not (re.match(r'^\s*%\w+ = add i8 0, [01]\s*$', x)
                                      and re.match(r'^\s*(%\w+)', x).group(1) in dead)] # type: ignore
        names = {}
        lab = {}

        def fix(x):
            x = re.sub(r'%t\d+(?![\w.])', lambda m: names.setdefault(m.group(0), f"%r{len(names)}"), x)

            def lb(m):
                nm, suf = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
                return nm + re.sub(r'\d+', lambda n: str(lab.setdefault(n.group(0), len(lab))), suf)
            return re.sub(r'(?<=label %)([A-Za-z_]+?)((?:_\d+)+)\b|^([A-Za-z_]+?)((?:_\d+)+)(?=:)', lb, x)
        res.extend(fix(x) for x in kept)
        fn.clear()

    for l in out:                          # per function: drop dead flag temps, renumber the rest in order of appearance
        if l.startswith("define"):
            flush()
        fn.append(l)
    flush()
    return res


args = sys.argv[1:]
stems = sorted(os.path.basename(p)[:-4] for p in glob.glob("decomp_out\\*.mch"))
if args and args[0].isdigit():
    stems = stems[:int(args[0])]
elif args:
    stems = args

same, diff, failed = [], [], []
for s in stems:
    out = os.path.join("decomp_out", s)
    if os.path.exists(out + ".ll"):
        os.remove(out + ".ll")
    r = subprocess.run(["python", "mocha_compile.py", out + ".mch", out], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if os.path.exists(out + ".exe"):
        os.remove(out + ".exe")
    if not os.path.exists(out + ".ll"):
        failed.append(s)
        print(f"FAIL  {s}")
        for l in [x.strip() for x in (r.stdout + r.stderr).splitlines() if x.strip()][-3:]:
            print("      " + l[:150])
        continue
    d = [l for l in difflib.unified_diff(lines(f"corpus_current\\{s}.ll"), lines(out + ".ll"), lineterm="", n=int(os.environ.get("CTX", "0")))
         if not l.startswith(("---", "+++", "@@"))]
    if d:
        diff.append(s)
        print(f"DIFF  {s}  ({len(d)} lines)")
        for l in d[:int(os.environ.get("SHOW", "4"))]:
            print("      " + l[:150])
    else:
        same.append(s)
        print(".", end="", flush=True)     # SAME: one dot, so the long run shows progress

print()
print(f"\nSAME: {len(same)}   DIFF: {len(diff)}   FAIL (won't compile): {len(failed)}")