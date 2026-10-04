$proc = Start-Process -FilePath "C:\Users\shiv jain\Coding_Projects\My_Codes\Mocha\Python_AND_ExecutableFiles\bert_sentiment_anal.exe" -NoNewWindow -PassThru
$null = $proc.Handle
while (-not $proc.HasExited) {
    $proc.Refresh()
    Write-Host ("{0:N1} MB" -f ($proc.WorkingSet64 / 1MB))
    Start-Sleep -Milliseconds 100
}
Write-Host "Done. Final exit code: $($proc.ExitCode)"