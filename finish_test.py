# finish_test.py  (run from the PROJECT folder)
#   python finish_test.py 20            first 20 decompiled files
#   python finish_test.py name1 name2   just these
import sys, os, glob, subprocess, difflib, re


def lines(path):
    out = []
    for l in open(path, encoding="utf-8"):
        if not l.strip() or l.startswith("declare"):
            continue
        l = re.sub(r'(@mocha_stack_update_line\(i32) \d+\)', r'\1 N)', l.rstrip())
        l = re.sub(r'(@mocha_stack_push\(.*, i32) \d+\)', r'\1 N)', l)
        out.append(l)
    return out


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
    d = [l for l in difflib.unified_diff(lines(f"corpus_current\\{s}.ll"), lines(out + ".ll"), lineterm="", n=0)
         if not l.startswith(("---", "+++", "@@"))]
    if d:
        diff.append(s)
        print(f"DIFF  {s}  ({len(d)} lines)")
        for l in d[:4]:
            print("      " + l[:150])
    else:
        same.append(s)
        print(f"SAME  {s}")

print(f"\nSAME: {len(same)}   DIFF: {len(diff)}   FAIL (won't compile): {len(failed)}")