$outDir = "corpus_current"
New-Item -ItemType Directory -Force $outDir | Out-Null
$log = Join-Path $outDir "failures.txt"
"" | Set-Content $log

$ok = 0
$fail = @()
$files = Get-ChildItem -Filter *.mch | Sort-Object Name
$i = 0

foreach ($f in $files) {
    $i++
    $name = $f.BaseName
    $out = Join-Path $outDir $name
    Remove-Item "$out.ll" -ErrorAction SilentlyContinue   # never trust a stale file

    $text = & python mocha_compile.py $f.FullName $out 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and (Test-Path "$out.ll")) {
        Write-Host ("[{0}/{1}] OK    {2}" -f $i, $files.Count, $name) -ForegroundColor Green
        $ok++
        Remove-Item "$out.exe" -ErrorAction SilentlyContinue
    } else {
        Write-Host ("[{0}/{1}] FAIL  {2}" -f $i, $files.Count, $name) -ForegroundColor Red
        $fail += $name
        $tail = ($text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 4) -join "`n    "
        Add-Content $log "$name`n    $tail`n"
    }
}

Write-Host ""
Write-Host ("{0} compiled, {1} failed (details in {2})" -f $ok, $fail.Count, $log)
if ($fail.Count -gt 0) { Write-Host ("Failed: " + ($fail -join ", ")) -ForegroundColor Yellow }