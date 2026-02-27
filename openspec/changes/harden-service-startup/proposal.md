# Harden Service Startup and Exit Code Checking

## Problem

The Gemini code review identified two reliability gaps in `Set-LazyTime.ps1`:

1. **W32Time service startup uses a fixed `Start-Sleep -Seconds 2`** instead of polling for the `Running` state. On slower or heavily loaded machines, the service may take longer than 2 seconds to start, causing subsequent `w32tm /config` and `w32tm /resync` commands to fail.

2. **`sc.exe create` exit codes are not checked.** When creating the `lfsvc` service, `sc.exe` failures are logged but do not set `$remediationSuccess = $false`, meaning the script reports success despite a failed service creation.

## Solution

1. Replace fixed `Start-Sleep -Seconds 2` calls with a `Wait-ServiceRunning` helper function that polls `Get-Service` in a loop with a configurable timeout (default 30 seconds, polling every 2 seconds).

2. Add `$LASTEXITCODE` checking after `sc.exe create` calls, consistent with the existing pattern used for `w32tm` commands.

## Impact

- **Set-LazyTime.ps1** - Modified (helper function + 3 call sites updated)
- Risk: Low - defensive improvement, no behavioral change on fast-starting services
