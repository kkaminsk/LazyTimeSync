## Why

The current detection and remediation scripts deviate from Microsoft's documented Intune Remediation best practices in several areas. Aligning with these practices improves supportability (Collect Diagnostics integration), prevents disk exhaustion from unbounded log growth, and ensures console output stays within Intune's 2048-character limit.

## What Changes

1. **Logging Infrastructure Overhaul**
   - Switch from custom `Write-Log` to `Start-Transcript`/`Stop-Transcript` pattern
   - Add size-based log rotation (5MB threshold) with archive pruning
   - Add `finally` block to ensure transcript cleanup on all exit paths

2. **Console Output Discipline**
   - Detection: Keep single summary line (already compliant)
   - Remediation: Remove console output from `Write-Log`; reserve STDOUT for final status only

3. **Script Documentation**
   - Add `.SYNOPSIS` and `.DESCRIPTION` comment blocks per Microsoft template

4. **Log File Strategy**
   - Change from per-execution timestamped files to single file with rotation
   - Maintain backward compatibility with existing log cleanup

**NOT changing (intentional deviation):**
- Log location stays at `C:\ProgramData\LazyTime` per existing `time-sync` spec (brand consistency over IME integration)

## Impact

- Affected specs: `time-sync`
- Affected code: `Detect-LazyTime.ps1`, `Set-LazyTime.ps1`
- No breaking changes to Intune deployment configuration
- Log file naming will change (new pattern: `Detect-LazyTime.log`, `Remediate-LazyTime.log`)
