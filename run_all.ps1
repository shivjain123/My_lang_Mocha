param([switch]$SkipLibs)

# --- 1. libraries ---
$libsOk = $true
if (-not $SkipLibs) {
    Write-Host "=== Rebuilding libraries ===" -ForegroundColor Cyan
    & mocha libs
    $libsOk = ($LASTEXITCODE -eq 0)
    Write-Host ""
    Write-Host "=== Running tests ===" -ForegroundColor Cyan
}

# --- 2. find tests: test_a..test_z, then test_aa..test_zz (shortest name first, then alphabetical) ---
$names = Get-ChildItem -Filter "test_*.mch" |
    Where-Object { $_.BaseName -match '^test_[a-z]{1,2}$' } |
    Sort-Object @{ Expression = { $_.BaseName.Length } }, BaseName |
    ForEach-Object { $_.BaseName }

if (-not $names) { Write-Host "No test_*.mch files found in this folder." -ForegroundColor Yellow }

$limitMB = 9
$bad = @()

foreach ($n in $names) {
    & mocha "$n.mch" *> $null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$n.exe")) {
        Write-Host "$n  COMPILE FAIL" -ForegroundColor Red
        $bad += $n
        continue
    }

    $p = Start-Process ".\$n.exe" -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\rc_out.txt"
    $null = $p.Handle
    $peak = 0
    while (-not $p.HasExited) {
        $p.Refresh()
        $mb = [math]::Round($p.WorkingSet64 / 1MB, 1)
        if ($mb -gt $peak) { $peak = $mb }
        Start-Sleep -Milliseconds 50
    }
    $p.WaitForExit()
    $code = $p.ExitCode

    $verdict = "ok"
    if ($code -eq 97) { $verdict = "RC FATAL" }
    elseif ($code -ne 0) { $verdict = "EXIT $code" }
    elseif ($peak -gt $limitMB) { $verdict = "LEAK?" }

    $color = if ($verdict -eq "ok") { "Green" } else { "Red" }
    Write-Host ("{0,-10} peak {1,6} MB  exit {2,-4} {3}" -f $n, $peak, $code, $verdict) -ForegroundColor $color
    if ($verdict -ne "ok") { $bad += $n }
}

Write-Host ""
if (-not $libsOk) { Write-Host "LIBRARIES: some failed to build (see the list above)" -ForegroundColor Red }
if ($bad.Count -eq 0 -and $libsOk) { Write-Host "ALL CLEAN" -ForegroundColor Green }
elseif ($bad.Count -gt 0) { Write-Host ("PROBLEMS: " + ($bad -join ", ")) -ForegroundColor Red }