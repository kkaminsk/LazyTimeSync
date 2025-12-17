# LazyTimeSyncStuff

## Overview

Intune remediation scripts for Windows Time (W32Time) service configuration and monitoring. Ensures Windows devices synchronize with NTP servers and maintain accurate system time for Kerberos authentication, certificate validation, security logging, and Azure AD/Entra ID authentication.

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| PowerShell | 5.1+ | Scripting language |
| Windows | 10/11, Server 2016+ | Target OS |
| Microsoft Intune | N/A | Deployment platform |
| w32tm | Built-in | Windows Time service CLI |

## Project Structure

```
LazyTimeSyncStuff/
├── Detect-LazyTime.ps1   # Detection script (Intune compliance check)
├── Set-LazyTime.ps1      # Remediation script (configures W32Time)
├── Test-NTP.ps1          # Pre-deployment connectivity test
├── referencescript.ps1   # Original reference script
├── Graphics/             # Documentation images
├── openspec/             # OpenSpec specifications
└── README.md             # Full documentation
```

## Architecture

### Detection/Remediation Pattern

The project follows Intune's detection/remediation model:
1. **Detection** (`Detect-LazyTime.ps1`) - Checks compliance, exits 0 (compliant) or 1 (non-compliant)
2. **Remediation** (`Set-LazyTime.ps1`) - Runs only when detection fails, configures the system

### Data Flow

```
[Intune] -> [Detection Script] -> Exit 0? -> Done
                              |
                              -> Exit 1? -> [Remediation Script] -> Re-run Detection
```

## Coding Conventions

### PowerShell Style

- Use `$camelCase` for variable names
- Use `Verb-Noun` pattern for function names (e.g., `Get-NtpTime`, `Write-Log`, `Remove-OldLogs`)
- Include comment headers describing script purpose
- Use `-ErrorAction SilentlyContinue` for non-critical operations
- Wrap main logic in `try/catch` blocks

### Script Structure

All scripts follow this pattern:
1. Header comment explaining purpose
2. Configuration variables at top
3. Helper functions (`Remove-OldLogs`, `Write-Log`, etc.)
4. Main execution logic in try/catch
5. Explicit exit codes

### Logging

Both detection and remediation scripts share identical logging conventions:

```powershell
$logDir = "C:\ProgramData\LazyTime"
$logPath = "$logDir\W32Time-Intune-YYYY-MM-DD-HH-mm.log"
```

Log format:
```
[YYYY-MM-DD HH:mm:ss] [LEVEL] Message
```

Log levels: `INFO`, `WARNING`, `ERROR`

### Exit Codes

| Script | Exit 0 | Exit 1 |
|--------|--------|--------|
| Detection | Compliant | Non-compliant |
| Remediation | Success | Failure |
| Test-NTP | All servers reachable | Any server unreachable |

## Configuration Variables

### Keep in Sync

These variables must match between scripts:

| Variable | Script | Value |
|----------|--------|-------|
| `$ntpServers` | Set-LazyTime.ps1 | Comma-separated string |
| `$expectedNtpServers` | Detect-LazyTime.ps1 | Array of same servers |

### Shared Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `$logDir` | `C:\ProgramData\LazyTime` | Log file directory |
| `$logRetentionDays` | `30` | Days to keep log files |
| `$maxDriftSeconds` | `300` | Max allowed time drift (detection only) |

## Network Requirements

| Protocol | Port | Direction | Destination |
|----------|------|-----------|-------------|
| UDP | 123 | Outbound | `*.ca.pool.ntp.org` |

## Testing

### Pre-Deployment

Run `Test-NTP.ps1` to verify UDP 123 connectivity before deploying to devices behind firewalls.

### Manual Verification

```powershell
# Check service status
Get-Service W32Time

# View configuration
w32tm /query /configuration

# View peers
w32tm /query /peers

# Check sync status
w32tm /query /status

# Force sync
w32tm /resync /force
```

## Deployment

### Intune Settings

| Setting | Value |
|---------|-------|
| Run as | System (not logged-on user) |
| 64-bit PowerShell | Yes |
| Signature check | No (unless signed) |
| Schedule | Daily or every 8 hours |

## Security Considerations

- Scripts run as SYSTEM (elevated privileges)
- Logs stored in `C:\ProgramData` (admin accessible)
- NTP traffic is unencrypted UDP
- Consider internal NTP servers for high-security environments
