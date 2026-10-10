# build_wasm.ps1 - rebuild the CAPE demo for the browser
$env:ZIG_LIB_DIR = "$PSScriptRoot\zig-lib"
New-Item -ItemType Directory -Force wasm_build | Out-Null

# wasm32 has 32-bit sizes: route the IR's malloc(i64) through a 64-bit-sized shim
function Patch-IR($src, $dst) {
    $text = [IO.File]::ReadAllText((Resolve-Path $src))
    $text = $text -replace '@malloc\b', '@mocha_malloc64'
    [IO.File]::WriteAllText("$PSScriptRoot\$dst", $text, (New-Object Text.UTF8Encoding $false))
}
Patch-IR "lib\mocha-math.ll"    "wasm_build\mocha-math.ll"
Patch-IR "lib\mocha-meteoro.ll" "wasm_build\mocha-meteoro.ll"
Patch-IR "cape_demo.ll"         "wasm_build\cape_demo.ll"

zig cc -target wasm32-wasi -O2 -c mocha_runtime.c -o rt_wasm.o 2>&1 | Select-String "error"
zig cc -target wasm32-wasi -O2 -c wasm_build\mocha-math.ll -o wasm_build\mocha-math.o 2>&1 | Select-String "error"
zig cc -target wasm32-wasi -O2 -c wasm_build\mocha-meteoro.ll -o wasm_build\mocha-meteoro.o 2>&1 | Select-String "error"
zig cc -target wasm32-wasi -O2 -c wasm_build\cape_demo.ll -o wasm_build\cape_demo.o 2>&1 | Select-String "error"
zig cc -target wasm32-wasi -mexec-model=reactor "-Wl,--export=cape_demo" wasm_build\cape_demo.o wasm_build\mocha-meteoro.o wasm_build\mocha-math.o rt_wasm.o -o cape_demo.wasm 2>&1 | Select-String "error|undefined|mismatch"
Write-Host "build finished"