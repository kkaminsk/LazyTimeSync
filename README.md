# Windows Time Service (W32Time) Configuration for Intune

This repository contains PowerShell scripts for configuring and detecting Windows Time Service (W32Time) compliance via Microsoft Intune.

## Overview

Accurate time synchronization is critical for:
- Kerberos authentication (tickets are time-sensitive)
- Certificate validation
- Security logging and auditing
- Group Policy processing
- Azure AD/Entra ID authentication

These scripts ensure Windows devices are configured to synchronize with Canadian NTP pool servers and maintain accurate system time.

## Scripts

| Script | Purpose |
|--------|---------|
| `Test-NTP.ps1` | Pre-deployment test - Verifies outbound NTP connectivity |
| `Set-LazyTime.ps1` | Remediation script - Configures W32Time service, registers if needed, and sets NTP servers |
| `Detect-LazyTime.ps1` | Detection script - Validates configuration and time accuracy |

## Pre-Deployment Testing

![](/Graphics/Test-Final.png)

**Important:** Before deploying the W32Time scripts to devices behind firewalls, run `Test-NTP.ps1` to verify outbound NTP connectivity.

```powershell
.\Test-NTP.ps1
```

This script tests UDP port 123 connectivity to all configured NTP pool servers and reports:
- DNS resolution status
- NTP query response
- Time offset from each server

If any connectivity tests fail, ensure your firewall allows outbound UDP port 123 to the NTP pool servers before deploying the remediation scripts. DNS errors may also interfere with the test.

### Detect-LazyTime.ps1 The Detection Script

![](/Graphics/Remediation-Final.png)

### Set-LazyTime.ps1 The Remediation Script

![](/Graphics/Checks-Final.png)

## NTP Servers

The scripts are configured to use the Canadian NTP Pool Project servers:

- `0.ca.pool.ntp.org`
- `1.ca.pool.ntp.org`
- `2.ca.pool.ntp.org`
- `3.ca.pool.ntp.org`

To use different NTP servers, modify the `$ntpServers` variable in `Set-LazyTime.ps1` and the `$expectedNtpServers` array in `Detect-LazyTime.ps1`.

## Detection Criteria

The detection script (`Detect-LazyTime.ps1`) performs six checks:

| Check | Description | Failure Condition |
|-------|-------------|-------------------|
| Service Status | W32Time service must be running | Service stopped or not found |
| NTP Configuration | All expected NTP servers must be configured | Any server missing from configuration |
| Time Drift | Local time must be within tolerance of NTP time | Drift exceeds 300 seconds (5 minutes) |
| Geolocation Service | lfsvc service must be running | Service stopped or not found |
| Location Policies | LocationAndSensors registry policies must be set | DisableLocation, DisableWindowsLocationProvider, or DisableLocationScripting not 0 |
| Location Consent | CapabilityAccessManager consent must be "Allow" | Consent value not set to "Allow" |

### Exit Codes

| Exit Code | Output | Meaning |
|-----------|--------|---------|
| 0 | Compliant | All checks passed - device is compliant |
| 1 | Non-Compliant | One or more checks failed - remediation required |

## Intune Deployment

### Configuring the Remediation Script

1. Navigate to **Microsoft Intune admin center** > **Devices** > **Scripts and remediations** > **Remediations**
2. Click **Create** to create a new remediation
3. Configure as follows:

| Setting | Value |
|---------|-------|
| Name | Configure Windows Time Service (W32Time) |
| Description | Configures W32Time service with Canadian NTP pool servers |
| Detection script file | `Detect-LazyTime.ps1` |
| Remediation script file | `Set-LazyTime.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | No (or Yes if scripts are signed) |
| Run script in 64-bit PowerShell | Yes |

4. Assign to appropriate device groups
5. Configure schedule (recommended: Daily or every 8 hours)

### Standalone Script Deployment

If deploying as a standalone script (without detection):

1. Navigate to **Devices** > **Scripts and remediations** > **Platform scripts**
2. Click **Add** > **Windows 10 and later**
3. Upload `Set-LazyTime.ps1`
4. Configure:
   - Run this script using the logged-on credentials: **No**
   - Run script in 64-bit PowerShell: **Yes**

## Script Logging

Both scripts use PowerShell's `Start-Transcript` for comprehensive logging, following Microsoft Intune best practices.

### Log Location

| Setting | Value |
|---------|-------|
| Log Directory | `C:\ProgramData\LazyTime` |
| Detection Log | `Detect-LazyTime.log` |
| Remediation Log | `Remediate-LazyTime.log` |

### Log Rotation

Scripts implement automatic size-based log rotation to prevent disk exhaustion:

| Setting | Value |
|---------|-------|
| Max Log Size | 5 MB |
| Max Archives | 3 |
| Archive Pattern | `*.log.YYYYMMDD-HHmmss.old` |
| Retention Period | 30 days |

When a log file exceeds 5 MB, it is archived with a timestamp suffix. Only the 3 most recent archives are retained.

### Log Markers

| Marker | Description |
|--------|-------------|
| `[PASS]` | Check passed successfully |
| `[ERROR]` | Check failed or error occurred |
| `[WARNING]` | Non-critical issue |

### Console Output

To comply with Intune's 2048-character limit, console output is minimal:

| Script | Success Output | Failure Output |
|--------|----------------|----------------|
| Detection | `Compliant` | `Non-Compliant` |
| Remediation | `Remediation completed successfully` | `Remediation failed` |

Detailed logs are written only to the transcript file.

### Sample Log Output

**Detection Script:** `Detect-LazyTime.log`
```
**********************
Windows PowerShell transcript start
Start time: 20251220111932
**********************
========== Starting W32Time Detection ==========
Timestamp: 2025-12-20 11:19:32
Computer Name: WORKSTATION01
Check 1: Verifying W32Time service status
[PASS] W32Time service is running
Check 2: Verifying NTP server configuration
[PASS] NTP server '0.ca.pool.ntp.org' is configured
[PASS] All expected NTP servers are configured
Check 3: Verifying time drift is within 300 seconds
[PASS] Time drift is within acceptable range
========== Detection Result: COMPLIANT ==========
**********************
Windows PowerShell transcript end
**********************
```

### Legacy Log Cleanup

Scripts automatically clean up old log formats during execution:
- Legacy timestamped logs (`W32Time-Intune-*.log`) older than 30 days
- Archive files (`.old`) older than 30 days

## Troubleshooting

### Common Issues

#### Detection fails on "Service not running"

The W32Time service may be disabled or stopped. The remediation script will:
1. Set service startup type to Automatic
2. Start the service

#### Detection fails on "NTP servers not configured"

Possible causes:
- Remediation hasn't run yet
- Group Policy is overriding NTP settings
- Previous configuration was cleared

Check current configuration:
```powershell
w32tm /query /peers
w32tm /query /configuration
```

#### Detection fails on "Time drift exceeds maximum"

Possible causes:
- Network blocking UDP port 123
- Firewall rules preventing NTP traffic
- CMOS battery failure
- Virtualization time sync conflicts

Force resync manually:
```powershell
w32tm /resync /force
```

Check time source:
```powershell
w32tm /query /status
```

#### NTP queries timeout

Ensure the following:
- UDP port 123 is open outbound
- DNS can resolve `*.pool.ntp.org`
- No proxy intercepting UDP traffic

### Manual Verification Commands

```powershell
# Check service status
Get-Service W32Time

# View current time configuration
w32tm /query /configuration

# View configured peers
w32tm /query /peers

# Check synchronization status
w32tm /query /status

# Force time sync
w32tm /resync /force

# Check time against NTP server
w32tm /stripchart /computer:0.ca.pool.ntp.org /samples:3
```

## Network Requirements

| Protocol | Port | Direction | Destination |
|----------|------|-----------|-------------|
| UDP | 123 | Outbound | 0.ca.pool.ntp.org |
| UDP | 123 | Outbound | 1.ca.pool.ntp.org |
| UDP | 123 | Outbound | 2.ca.pool.ntp.org |
| UDP | 123 | Outbound | 3.ca.pool.ntp.org |

## Geolocation Service Configuration

The scripts also configure the Windows Geolocation Service (lfsvc) for location-based features.

### Registry Settings

| Registry Path | Value | Type | Expected |
|---------------|-------|------|----------|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors` | DisableLocation | DWORD | 0 |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors` | DisableWindowsLocationProvider | DWORD | 0 |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors` | DisableLocationScripting | DWORD | 0 |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location` | Value | String | Allow |

### Remediation Actions

The remediation script configures:
1. Creates LocationAndSensors registry key and sets all disable values to 0
2. Creates CapabilityAccessManager consent key and sets Value to "Allow"
3. Creates lfsvc service if missing (using sc.exe)
4. Sets lfsvc startup type to Manual and starts the service

## Configuration Customization

### Changing NTP Servers

**Set-LazyTime.ps1**:
```powershell
$ntpServers = "0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org"
```

**Detect-LazyTime.ps1**:
```powershell
$expectedNtpServers = @("0.ca.pool.ntp.org", "1.ca.pool.ntp.org", "2.ca.pool.ntp.org", "3.ca.pool.ntp.org")
```

### Changing Time Drift Tolerance

**Detect-LazyTime.ps1**:
```powershell
$maxDriftSeconds = 300  # 5 minutes
```

### Changing Log Paths

Both scripts use a `$logDir` variable at the top of the script that can be modified:
```powershell
$logDir = "C:\ProgramData\LazyTime"
```

### Changing Log Settings

Both scripts support these logging configuration variables:
```powershell
$logRetentionDays = 30   # Days to keep old logs
$maxLogSizeMB = 5        # Size threshold for rotation
$maxLogArchives = 3      # Number of archives to keep
```

## Security Considerations

- Scripts run as SYSTEM (elevated) - required for service management
- Log files are written to `C:\ProgramData\LazyTime` (accessible by admins)
- NTP traffic is unencrypted UDP - ensure trusted network path
- Consider using internal NTP servers in high-security environments

## License

This project is provided as-is for use in enterprise environments.

## References

- [Microsoft W32Time Documentation](https://docs.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-top)
- [NTP Pool Project](https://www.ntppool.org/)
- [Intune Remediations](https://docs.microsoft.com/en-us/mem/intune/fundamentals/remediations)
