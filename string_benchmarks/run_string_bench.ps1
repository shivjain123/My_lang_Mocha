# String Benchmark Suite
# Run from: benchmarks\String\ folder
# Compile all first, then run measurements

# ============================================================
# PRE-COMPILE (run once before benchmarking)
# ============================================================

# Mocha
# mocha string_bench.mch

# Java
# javac string_bench.java

# Rust
# rustc -O string_bench.rs -o string_bench_rust.exe

# C++
# clang++ -O3 string_bench.cpp -o string_bench_cpp.exe

# Python and JS need no compilation


# ============================================================
# BENCHMARK RUNNER
# ============================================================

Write-Host "============================================"
Write-Host "String Benchmark Suite — 10 runs each"
Write-Host "============================================"
Write-Host ""

# --- Mocha ---
Write-Host "=== MOCHA ==="
$mocha_times = 1..10 | ForEach-Object {
    (Measure-Command { & ".\string_bench.exe" }).TotalMilliseconds
}
$mocha_avg = ($mocha_times | Measure-Object -Average).Average
Write-Host "Runs: $($mocha_times -join ', ')"
Write-Host "Average: $([math]::Round($mocha_avg, 2)) ms"
Write-Host ""

# --- Java ---
Write-Host "=== JAVA ==="
$java_times = 1..10 | ForEach-Object {
    (Measure-Command { java string_bench }).TotalMilliseconds
}
$java_avg = ($java_times | Measure-Object -Average).Average
Write-Host "Runs: $($java_times -join ', ')"
Write-Host "Average: $([math]::Round($java_avg, 2)) ms"
Write-Host ""

# --- Python ---
Write-Host "=== PYTHON ==="
$py_times = 1..10 | ForEach-Object {
    (Measure-Command { python string_bench.py }).TotalMilliseconds
}
$py_avg = ($py_times | Measure-Object -Average).Average
Write-Host "Runs: $($py_times -join ', ')"
Write-Host "Average: $([math]::Round($py_avg, 2)) ms"
Write-Host ""

# --- JavaScript ---
Write-Host "=== JAVASCRIPT (Node) ==="
$js_times = 1..10 | ForEach-Object {
    (Measure-Command { node string_bench.js }).TotalMilliseconds
}
$js_avg = ($js_times | Measure-Object -Average).Average
Write-Host "Runs: $($js_times -join ', ')"
Write-Host "Average: $([math]::Round($js_avg, 2)) ms"
Write-Host ""

# --- Rust ---
Write-Host "=== RUST ==="
$rust_times = 1..10 | ForEach-Object {
    (Measure-Command { & ".\string_bench_rust.exe" }).TotalMilliseconds
}
$rust_avg = ($rust_times | Measure-Object -Average).Average
Write-Host "Runs: $($rust_times -join ', ')"
Write-Host "Average: $([math]::Round($rust_avg, 2)) ms"
Write-Host ""

# --- C++ ---
Write-Host "=== C++ ==="
$cpp_times = 1..10 | ForEach-Object {
    (Measure-Command { & ".\string_bench_cpp.exe" }).TotalMilliseconds
}
$cpp_avg = ($cpp_times | Measure-Object -Average).Average
Write-Host "Runs: $($cpp_times -join ', ')"
Write-Host "Average: $([math]::Round($cpp_avg, 2)) ms"
Write-Host ""

# ============================================================
# SUMMARY TABLE
# ============================================================

Write-Host "============================================"
Write-Host "RESULTS SUMMARY"
Write-Host "============================================"
Write-Host "Language    | Avg Time (ms) | vs Mocha"
Write-Host '------------|---------------|----------'

$langs = @(
    @{Name="Mocha";      Avg=$mocha_avg},
    @{Name="C++";        Avg=$cpp_avg},
    @{Name="Rust";       Avg=$rust_avg},
    @{Name="Java";       Avg=$java_avg},
    @{Name="JavaScript"; Avg=$js_avg},
    @{Name="Python";     Avg=$py_avg}
)

$sorted = $langs | Sort-Object { $_.Avg }

foreach ($lang in $sorted) {
    $ratio = [math]::Round($lang.Avg / $mocha_avg, 2)
    $vs = if ($lang.Name -eq "Mocha") { "baseline" } 
          elseif ($ratio -gt 1) { ($ratio.ToString() + "x slower") }
          else { "$([math]::Round(1/$ratio, 2))x faster" }
    $name = $lang.Name.PadRight(11)
    $avg  = "$([math]::Round($lang.Avg, 2))".PadRight(13)
    Write-Host ($name + ' | ' + $avg + ' | ' + $vs)
}

Write-Host "============================================"
Write-Host ""
Write-Host "Benchmarks:"
Write-Host "  1. String concat loop x10000"
Write-Host "  2. String contains search x10000"
Write-Host "  3. String reverse x10000"
Write-Host "  4. String split x10000"
Write-Host ""
Write-Host "Notes:"
Write-Host "  Java uses StringBuilder (fair comparison)"
Write-Host '  C++ uses reserve() pre-allocation'
Write-Host '  Rust uses push_str()'
Write-Host "  All measured with PowerShell Measure-Command"
Write-Host "  Wall clock time including startup"
