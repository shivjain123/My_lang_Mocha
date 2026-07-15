$proc = Start-Process -FilePath "C:\Users\shiv jain\Coding_Projects\My_Codes\Mocha\Python_AND_ExecutableFiles\rc_2dArray_test.exe" -NoNewWindow -PassThru
while (-not $proc.HasExited) {
    $proc.Refresh()
    Write-Host ("{0:N1} MB" -f ($proc.WorkingSet64 / 1MB))
    Start-Sleep -Milliseconds 100
}
Write-Host "Done. Final exit code: $($proc.ExitCode)"