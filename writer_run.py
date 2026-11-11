# writer_run.py  (run from corpus_current\)
import os, glob, collections, traceback
from mocha_writer import write_module

os.makedirs("..\\decomp_out", exist_ok=True)
ok, fail, reasons, ex = 0, 0, collections.Counter(), {}
for f in sorted(glob.glob("*.ll")):
    stem = f[:-3]
    try:
        text = write_module(open(f, encoding="utf-8").read())
        open(os.path.join("..", "decomp_out", stem + ".mch"), "w", encoding="utf-8", newline="\n").write(text)
        ok += 1
    except Exception as e:
        fail += 1
        if fail == 1:
            import traceback; traceback.print_exc()
        r = f"{type(e).__name__}: {str(e)[:100]}"
        reasons[r] += 1
        ex.setdefault(r, stem)

print(f"written: {ok}   failed: {fail}")
for r, n in reasons.most_common(15):
    print(f"  {n:4d} x {r}\n         e.g. {ex[r]}")