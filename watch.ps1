param([string]$exe)
$proc = Start-Process -FilePath (Resolve-Path $exe).Path -NoNewWindow -PassThru
$null = $proc.Handle
while (-not $proc.HasExited) {
    $proc.Refresh()
    Write-Host ("{0:N1} MB" -f ($proc.WorkingSet64 / 1MB))
    Start-Sleep -Milliseconds 100
}
Write-Host "Done. Final exit code: $($proc.ExitCode)"