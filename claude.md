<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# LazyTimeSyncStuff

Intune remediation scripts for Windows Time (W32Time) service configuration and monitoring.

## Project Structure

```
├── Detect-LazyTime.ps1   # Detection script (Intune compliance check)
├── Set-LazyTime.ps1      # Remediation script (configures W32Time)
├── Test-NTP.ps1          # Pre-deployment connectivity test
├── referencescript.ps1   # Original reference script (simplified version)
├── Graphics/             # Documentation images
│   ├── Detect.png
│   └── Remediate.png
└── README.md             # Full documentation
```

## Scripts Overview

### Detect-LazyTime.ps1
Detection script that performs six compliance checks:
1. **Service Status** - W32Time service must be running
2. **NTP Configuration** - All expected NTP servers must be configured
3. **Time Drift** - Local time must be within 300 seconds of NTP time
4. **Geolocation Service** - lfsvc service must be running
5. **Location Policies** - LocationAndSensors registry policies must allow location
6. **Location Consent** - CapabilityAccessManager consent must be "Allow"

Exit codes: `0` = Compliant, `1` = Non-compliant

### Set-LazyTime.ps1
Remediation script that:
1. Sets W32Time service to Automatic startup
2. Starts the service if not running
3. Registers the service if needed (`w32tm /register`)
4. Configures NTP servers via `w32tm /config`
5. Forces immediate time sync via `w32tm /resync`
6. Creates LocationAndSensors registry policies (DisableLocation=0, etc.)
7. Sets CapabilityAccessManager consent to "Allow"
8. Creates lfsvc service if missing
9. Sets lfsvc to Manual startup and starts it

### Test-NTP.ps1
Pre-deployment test that verifies UDP 123 connectivity to NTP servers. Run before deploying to ensure firewall rules allow NTP traffic.

## Key Configuration Variables

| Variable | Location | Default Value |
|----------|----------|---------------|
| `$ntpServers` | Set-LazyTime.ps1 | `0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org` |
| `$expectedNtpServers` | Detect-LazyTime.ps1 | Array of same servers |
| `$maxDriftSeconds` | Detect-LazyTime.ps1 | `300` (5 minutes) |
| `$logDir` | Both scripts | `C:\ProgramData\LazyTime` |
| `$logRetentionDays` | Both scripts | `30` |
| `$geolocationServiceName` | Both scripts | `lfsvc` |
| `$locationPolicyPath` | Both scripts | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors` |
| `$locationConsentPath` | Both scripts | `HKLM:\...\CapabilityAccessManager\ConsentStore\location` |

## Important Patterns

### Logging
Both detection and remediation scripts use identical logging:
- Log path: `C:\ProgramData\LazyTime\W32Time-Intune-YYYY-MM-DD-HH-mm.log`
- Format: `[YYYY-MM-DD HH:mm:ss] [LEVEL] Message`
- Levels: `INFO`, `WARNING`, `ERROR`
- Auto-cleanup of logs older than 30 days

### NTP Time Query
`Detect-LazyTime.ps1` contains a `Get-NtpTime` function that directly queries NTP servers using UDP sockets (port 123) to calculate time drift without relying on w32tm.

## Intune Deployment

- **Run as**: System (not logged-on user)
- **64-bit PowerShell**: Yes
- **Detection**: Detect-LazyTime.ps1
- **Remediation**: Set-LazyTime.ps1

## Network Requirements

- **Protocol**: UDP
- **Port**: 123 (outbound)
- **Destinations**: `*.ca.pool.ntp.org`

## When Modifying

- Keep `$ntpServers` in Set-LazyTime.ps1 and `$expectedNtpServers` in Detect-LazyTime.ps1 synchronized
- Both scripts share the same log directory and retention settings
- The detection script's `Get-NtpTime` function uses raw socket communication - test changes carefully
