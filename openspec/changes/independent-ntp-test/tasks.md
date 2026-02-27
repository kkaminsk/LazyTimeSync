# Tasks: Independent NTP Test

- [x] Copy `Get-NtpTime` function from `Detect-LazyTime.ps1` into `Test-NTP.ps1`
- [x] Replace `w32tm /stripchart` test loop with `Get-NtpTime` raw UDP socket calls
- [x] Calculate and display time offset from NTP response
- [x] Preserve existing DNS resolution pre-check
- [x] Preserve existing result summary table and exit code logic
