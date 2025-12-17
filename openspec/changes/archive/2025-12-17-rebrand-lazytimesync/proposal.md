## Why

The current naming uses "LazyW32Time" and "LazyW32TimeandLocationServices" which is verbose and inconsistent. Rebranding to "LazyTimeSync" provides a cleaner, shorter name that better reflects the project's purpose while maintaining the "Lazy" prefix for brand consistency.

## What Changes

- **Script Renames**:
  - `Detect-LazyW32Time.ps1` → `Detect-LazyTime.ps1`
  - `Set-LazyW32TimeandLocationServices.ps1` → `Set-LazyTime.ps1`
- **Log Directory**: `C:\ProgramData\LazyW32TimeandLoc` → `C:\ProgramData\LazyTime`
- **Documentation Updates**: Update CLAUDE.md and README.md to reflect new script names and log paths

## Impact

- Affected code:
  - `Detect-LazyW32Time.ps1` (rename and update `$logDir`)
  - `Set-LazyW32TimeandLocationServices.ps1` (rename and update `$logDir`)
  - `CLAUDE.md` (update all references)
  - `README.md` (update all references)
- Breaking changes: Existing log files at old path will not be cleaned up by new scripts; administrators may want to manually delete `C:\ProgramData\LazyW32TimeandLoc` after deployment
