$outDir = "corpus_current"
foreach ($name in $args) {
    $out = Join-Path $outDir $name
    Remove-Item "$out.ll" -ErrorAction SilentlyContinue
    & python mocha_compile.py "$name.mch" $out 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path "$out.ll")) {
        Write-Host "OK    $name" -ForegroundColor Green
        Remove-Item "$out.exe" -ErrorAction SilentlyContinue
    } else {
        Write-Host "FAIL  $name" -ForegroundColor Red
    }
}