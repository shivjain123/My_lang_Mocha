"""mocha_libs.py - rebuild libraries: `mocha --lib lib/x.mch`, for all of them at once.
   mocha libs              rebuild every lib/*.mch
   mocha libs math string  rebuild just those (the "mocha-" prefix is optional)"""
import glob, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
COMPILER = os.path.join(HERE, "mocha_compile.py")

def build(path):
    env = dict(os.environ, PYTHONIOENCODING="utf-8")      # the compiler prints emojis; a pipe would choke on them
    r = subprocess.run([sys.executable, COMPILER, "--lib", path], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", env=env, cwd=HERE)
    return r.returncode == 0, (r.stdout + r.stderr)

def rebuild(names=None):
    libs = sorted(glob.glob(os.path.join(HERE, "lib", "*.mch")))
    if names:
        wanted = {(n if n.lower().startswith("mocha-") else "mocha-" + n).lower() for n in names}
        libs = [p for p in libs if os.path.splitext(os.path.basename(p))[0].lower() in wanted]
    if not libs:
        print("  ❌ No matching libraries found in lib/")
        return 1
    print(f"  ⚙️  Rebuilding {len(libs)} librar{'y' if len(libs) == 1 else 'ies'}...")
    start, failed, logs = time.time(), [], {}
    for rnd in (1, 2):                      # round 2 retries failures: a lib may need one that was built later
        todo = libs if rnd == 1 else failed
        failed = []
        for p in todo:
            name = os.path.splitext(os.path.basename(p))[0]
            t0 = time.time()
            ok, out = build(p)
            logs[name] = out
            if ok:
                print(f"     ✅ {name} ({time.time() - t0:.1f}s)")
            else:
                failed.append(p)
                if rnd == 1:
                    print(f"     ↻ {name} failed, will retry after the others")
        if not failed:
            break
    for p in failed:
        name = os.path.splitext(os.path.basename(p))[0]
        print(f"     ❌ {name}:")
        for line in logs[name].strip().splitlines()[-8:]:
            print("        " + line)
    done = len(libs) - len(failed)
    print(f"  {'✅' if not failed else '⚠️ '} {done}/{len(libs)} libraries built in {time.time() - start:.0f}s")
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(rebuild(sys.argv[1:]))