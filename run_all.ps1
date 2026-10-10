$names = @()
foreach ($c in [char[]]([int][char]'a'..[int][char]'z')) { $names += "test_$c" }
foreach ($c in [char[]]([int][char]'a'..[int][char]'z')) { $names += "test_a$c" }
foreach ($c in [char[]]([int][char]'b'..[int][char]'p')) { $names += "test_b$c" }

$limitMB = 15
$bad = @()

foreach ($n in $names) {
    if (-not (Test-Path "$n.mch")) { Write-Host "$n  (no .mch, skipped)"; continue }

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
if ($bad.Count -eq 0) { Write-Host "ALL CLEAN" -ForegroundColor Green }
else { Write-Host ("PROBLEMS: " + ($bad -join ", ")) -ForegroundColor Red }