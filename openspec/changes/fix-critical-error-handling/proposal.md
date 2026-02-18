## Why

The code audit identified critical and high-severity error handling issues. Service cmdlets in Set-LazyTime.ps1 lack `-ErrorAction Stop`, meaning failures produce non-terminating errors that the try/catch block silently ignores — reporting success when remediation actually failed. Additionally, `w32tm` exit codes are never checked, and the NTP socket in Detect-LazyTime.ps1 leaks on exceptions.

## What Changes

- **Set-LazyTime.ps1**: Add `-ErrorAction Stop` to `Set-Service`, `Start-Service`, `Restart-Service` calls for W32Time service. Check `$LASTEXITCODE` after `w32tm /config` and `w32tm /resync` commands. Add granular per-step try/catch blocks.
- **Detect-LazyTime.ps1**: Wrap socket operations in `Get-NtpTime` with try/finally to ensure `$socket.Dispose()` is always called. Add descriptive comment for NTP magic number `0x1B`.

## Impact

- Affected scripts: `Set-LazyTime.ps1`, `Detect-LazyTime.ps1`
- No breaking changes to exit codes or external behavior
- Improves reliability of error detection and resource cleanup
