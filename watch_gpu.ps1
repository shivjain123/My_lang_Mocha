param([string]$exe)
$p = Start-Process -FilePath $exe -PassThru -NoNewWindow
$null = $p.Handle
$first = $null
$peak = 0
while (-not $p.HasExited) {
    $mb = [int](nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | Select-Object -First 1)
    if ($null -eq $first) { $first = $mb }
    if ($mb -gt $peak) { $peak = $mb }
    Write-Host "$mb MB"
    Start-Sleep -Milliseconds 50
}
$p.WaitForExit()
Write-Host "start $first MB, peak $peak MB, exit $($p.ExitCode)"