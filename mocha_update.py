"""mocha_update.py - `mocha update` and the once-a-day "new version available" notice.
   python mocha_update.py update    pull the latest compiler (git pull --ff-only)
   python mocha_update.py check     print a one-line notice if origin has a newer commit"""
import os, subprocess, sys, time

HERE  = os.path.dirname(os.path.abspath(__file__))
STAMP = os.path.join(HERE, ".mocha_update_check")
DAY   = 24 * 3600

def git(*args, timeout=None):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")      # never hang on a password prompt
    try:
        r = subprocess.run(["git", "-C", HERE, *args], capture_output=True, text=True,
                           encoding="utf-8", timeout=timeout, env=env)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except FileNotFoundError:
        return 127, "", "git is not installed"
    except subprocess.TimeoutExpired:
        return 124, "", "timed out"

def touch_stamp():
    try:
        with open(STAMP, "w") as f:
            f.write(str(int(time.time())))
    except OSError:
        pass

def check():
    """At most once a day: say so if origin has a commit we don't have. Never raises, waits at most 3 s."""
    try:
        if os.environ.get("MOCHA_NO_UPDATE_CHECK"):
            return
        if os.path.exists(STAMP) and time.time() - os.path.getmtime(STAMP) < DAY:
            return
        touch_stamp()                      # counts even when offline, so an offline user waits once a day at most
        code, branch, _ = git("branch", "--show-current")
        if code != 0 or not branch:
            return
        code, out, _ = git("ls-remote", "origin", f"refs/heads/{branch}", timeout=3)
        if code != 0 or not out:
            return
        remote = out.split()[0]
        code, _, _ = git("merge-base", "--is-ancestor", remote, "HEAD")
        if code != 0:                      # remote commit is not in our history: there is something new
            print("  🔔 A new Mocha version is available. Run: mocha update")
    except Exception:
        pass

def update():
    code, inside, _ = git("rev-parse", "--is-inside-work-tree")
    if code != 0 or inside != "true":
        print("  ❌ This Mocha install is not a git clone, so it can't update itself.")
        print("     Get the latest from https://github.com/shivjain123/My_lang_Mocha")
        return 1
    code, branch, _ = git("branch", "--show-current")
    if not branch:
        print("  ❌ Not on a branch (detached HEAD). Switch to a branch first.")
        return 1
    _, before, _ = git("rev-parse", "HEAD")
    print("  ⬇️  Updating Mocha...")
    code, out, err = git("pull", "--ff-only", "origin", branch, timeout=300)
    if code != 0:
        print("  ❌ Update failed:")
        print("     " + (err or out).replace("\n", "\n     "))
        print("     Your own commits on this branch, or edits to files this update also changes, block it.")
        print("     To drop your edits to a file and retry:  git checkout -- <file>")
        return 1
    touch_stamp()
    _, after, _ = git("rev-parse", "HEAD")
    if before == after:
        print("  ✅ Already up to date.")
    else:
        _, log, _ = git("log", "--format=%s", "-n", "10", f"{before}..{after}")
        print("  ✅ Updated. What's new:")
        for line in log.splitlines():
            print("     - " + (line if len(line) <= 100 else line[:97] + "..."))
    return 0

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "update"
    if cmd == "check":
        check()
        sys.exit(0)
    sys.exit(update())