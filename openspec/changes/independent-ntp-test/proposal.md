# Independent NTP Test Using Raw UDP Socket

## Problem

The Gemini code review identified that `Test-NTP.ps1` relies on `w32tm /stripchart` for NTP connectivity testing. This command depends on the local W32Time service being functional. If W32Time is disabled or broken on the admin's machine, `Test-NTP.ps1` may yield false negatives, undermining its purpose as a pre-deployment connectivity check.

## Solution

Replace the `w32tm /stripchart` approach in `Test-NTP.ps1` with the raw UDP socket `Get-NtpTime` function already proven in `Detect-LazyTime.ps1`. This makes the test completely independent of the local W32Time service state, testing only network connectivity (UDP 123) and NTP server responsiveness.

The function will be duplicated into `Test-NTP.ps1` (intentional - same pattern as the shared log rotation functions, since each script must be self-contained).

## Impact

- **Test-NTP.ps1** - Modified (w32tm dependency removed, Get-NtpTime added)
- Risk: Low - the UDP socket method is already battle-tested in detection script
