import subprocess
r = subprocess.run(["nvcc", "--version"], capture_output=True, text=True)
print(r.stdout)
print(r.stderr)