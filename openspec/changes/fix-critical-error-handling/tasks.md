## 1. Set-LazyTime.ps1 Error Handling

- [x] 1.1 Add `-ErrorAction Stop` to `Set-Service -Name $serviceName -StartupType Automatic`
- [x] 1.2 Add `-ErrorAction Stop` to `Start-Service -Name $serviceName`
- [x] 1.3 Add `-ErrorAction Stop` to `Restart-Service -Name $serviceName -Force`
- [x] 1.4 Check `$LASTEXITCODE` after `w32tm /config` and set `$remediationSuccess = $false` on failure
- [x] 1.5 Check `$LASTEXITCODE` after `w32tm /resync` and set `$remediationSuccess = $false` on failure

## 2. Detect-LazyTime.ps1 Socket Fix

- [x] 2.1 Wrap socket operations in `Get-NtpTime` with try/finally to ensure `$socket.Dispose()` on error
- [x] 2.2 Add descriptive comment for NTP request header byte `0x1B`
