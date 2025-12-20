## 1. Add Logging Helper Function

- [x] 1.1 Create `Invoke-LogRotation` function (check size, archive if >5MB, prune old archives)
- [x] 1.2 Add function to both `Detect-LazyTime.ps1` and `Set-LazyTime.ps1`

## 2. Refactor Detection Script Logging

- [x] 2.1 Add `.SYNOPSIS` and `.DESCRIPTION` comment block
- [x] 2.2 Change log file name from timestamped to fixed (`Detect-LazyTime.log`)
- [x] 2.3 Add `Invoke-LogRotation` call before `Start-Transcript`
- [x] 2.4 Replace custom `Write-Log` calls with `Write-Output` (for transcript capture)
- [x] 2.5 Wrap main logic in `try { } catch { } finally { Stop-Transcript }`
- [x] 2.6 Keep console output minimal (single "Compliant" or "Non-Compliant" line)

## 3. Refactor Remediation Script Logging

- [x] 3.1 Add `.SYNOPSIS` and `.DESCRIPTION` comment block
- [x] 3.2 Change log file name from timestamped to fixed (`Remediate-LazyTime.log`)
- [x] 3.3 Add `Invoke-LogRotation` call before `Start-Transcript`
- [x] 3.4 Remove console output from `Write-Log` (keep only file logging)
- [x] 3.5 Wrap main logic in `try { } catch { } finally { Stop-Transcript }`
- [x] 3.6 Add single summary line at end for Intune console

## 4. Update Legacy Log Cleanup

- [x] 4.1 Modify `Remove-OldLogs` to also clean up old timestamped log files (migration)
- [x] 4.2 Add cleanup for `.old` archive files beyond retention limit

## 5. Validation

- [x] 5.1 Test detection script returns correct exit codes
- [x] 5.2 Test remediation script applies all configurations
- [x] 5.3 Verify log rotation triggers at 5MB threshold
- [x] 5.4 Verify console output under 2048 characters
- [x] 5.5 Test transcript captures all operations
