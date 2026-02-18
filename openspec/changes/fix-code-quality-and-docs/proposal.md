## Why

The code audit identified medium and low-priority improvements: the lfsvc detection check causes a perpetual remediation loop (demand-start service stops after inactivity, triggering re-remediation), README images are swapped between detection and remediation sections, claude.md project structure is outdated, scripts lack `#Requires` directives and version tracking, and intentional code duplication is undocumented.

## What Changes

- **Detect-LazyTime.ps1**: Change lfsvc check from requiring "Running" to requiring "not Disabled" (exists and startup type is not Disabled). Add `#Requires -Version 5.1`.
- **Set-LazyTime.ps1**: Add `#Requires -Version 5.1`. Add `$scriptVersion` variable. Add comment about intentional helper function duplication.
- **Detect-LazyTime.ps1**: Add `$scriptVersion` variable. Add comment about intentional helper function duplication.
- **Test-NTP.ps1**: Add `$scriptVersion` variable.
- **README.md**: Swap detection/remediation image references.
- **claude.md**: Update project structure to reflect current repository layout.

## Impact

- Affected files: `Detect-LazyTime.ps1`, `Set-LazyTime.ps1`, `Test-NTP.ps1`, `README.md`, `claude.md`
- **Behavior change**: lfsvc detection no longer requires running state, breaking the remediation loop
- No breaking changes to exit code semantics
