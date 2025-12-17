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
| `Set-W32Time.ps1` | Remediation script - Configures W32Time service, registers if needed, and sets NTP servers |
| `Detect-W32Time.ps1` | Detection script - Validates configuration and time accuracy |

## Pre-Deployment Testing

**Important:** Before deploying the W32Time scripts to devices behind firewalls, run `Test-NTP.ps1` to verify outbound NTP connectivity.

```powershell
.\Test-NTP.ps1
```

This script tests UDP port 123 connectivity to all configured NTP pool servers and reports:
- DNS resolution status
- NTP query response
- Time offset from each server

If any tests fail, ensure your firewall allows outbound UDP port 123 to the NTP pool servers before deploying the remediation scripts.

### Detect-W32Time.ps1 The Detection Script

![](/Graphics/Detect.png)

### Set-W32Time.ps1 The Remediation Script

![](/Graphics/Remediate.png)

## NTP Servers

The scripts are configured to use the Canadian NTP Pool Project servers:

- `0.ca.pool.ntp.org`
- `1.ca.pool.ntp.org`
- `2.ca.pool.ntp.org`
- `3.ca.pool.ntp.org`

To use different NTP servers, modify the `$ntpServers` variable in `Set-W32Time.ps1` and the `$expectedNtpServers` array in `Detect-W32Time.ps1`.

## Detection Criteria

The detection script (`Detect-W32Time.ps1`) performs three checks:

| Check | Description | Failure Condition |
|-------|-------------|-------------------|
| Service Status | W32Time service must be running | Service stopped or not found |
| NTP Configuration | All expected NTP servers must be configured | Any server missing from configuration |
| Time Drift | Local time must be within tolerance of NTP time | Drift exceeds 300 seconds (5 minutes) |

### Exit Codes

| Exit Code | Output | Meaning |
|-----------|--------|---------|
| 0 | Compliant | All checks passed - device is compliant |
| 1 | Non-Compliant | One or more checks failed - remediation required |

## Intune Deployment

### Remediation Script Deployment

1. Navigate to **Microsoft Intune admin center** > **Devices** > **Scripts and remediations** > **Remediations**
2. Click **Create** to create a new remediation
3. Configure as follows:

| Setting | Value |
|---------|-------|
| Name | Configure Windows Time Service (W32Time) |
| Description | Configures W32Time service with Canadian NTP pool servers |
| Detection script file | `Detect-W32Time.ps1` |
| Remediation script file | `Set-W32Time.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | No (or Yes if scripts are signed) |
| Run script in 64-bit PowerShell | Yes |

4. Assign to appropriate device groups
5. Configure schedule (recommended: Daily or every 8 hours)

### Standalone Script Deployment

If deploying as a standalone script (without detection):

1. Navigate to **Devices** > **Scripts and remediations** > **Platform scripts**
2. Click **Add** > **Windows 10 and later**
3. Upload `Set-W32Time.ps1`
4. Configure:
   - Run this script using the logged-on credentials: **No**
   - Run script in 64-bit PowerShell: **Yes**

## Logging

Both scripts write logs to `C:\ProgramData\W32Time\` using timestamped filenames:

| Log File Pattern | Description |
|------------------|-------------|
| `W32Time-Intune-YYYY-MM-DD-HH-mm.log` | New log file created each run |

### Log Retention

- Each script execution creates a new log file with the current timestamp
- Logs older than **30 days** are automatically deleted at the start of each script run
- Retention period can be adjusted via the `$logRetentionDays` variable in each script

### Log Format

```
[YYYY-MM-DD HH:mm:ss] [LEVEL] Message
```

### Log Levels

- `INFO` - Informational messages
- `WARNING` - Non-critical issues
- `ERROR` - Failures requiring attention

### Sample Log Output

**Detection Script (Success):** `W32Time-Intune-2025-12-16-10-30.log`
```
[2025-12-16 10:30:00] [INFO] ========== Starting W32Time Detection ==========
[2025-12-16 10:30:00] [INFO] Computer Name: WORKSTATION01
[2025-12-16 10:30:00] [INFO] Check 1: Verifying W32Time service status
[2025-12-16 10:30:00] [INFO] W32Time service is running - PASS
[2025-12-16 10:30:00] [INFO] Check 2: Verifying NTP server configuration
[2025-12-16 10:30:00] [INFO] NTP server '0.ca.pool.ntp.org' is configured - PASS
[2025-12-16 10:30:00] [INFO] NTP server '1.ca.pool.ntp.org' is configured - PASS
[2025-12-16 10:30:00] [INFO] NTP server '2.ca.pool.ntp.org' is configured - PASS
[2025-12-16 10:30:00] [INFO] NTP server '3.ca.pool.ntp.org' is configured - PASS
[2025-12-16 10:30:00] [INFO] All expected NTP servers are configured - PASS
[2025-12-16 10:30:00] [INFO] Check 3: Verifying time drift is within 300 seconds
[2025-12-16 10:30:00] [INFO] Attempting to query time from 0.ca.pool.ntp.org
[2025-12-16 10:30:00] [INFO] Successfully retrieved time from 0.ca.pool.ntp.org
[2025-12-16 10:30:00] [INFO] NTP Server (0.ca.pool.ntp.org) time (UTC): 2025-12-16 15:30:00
[2025-12-16 10:30:00] [INFO] Local system time (UTC): 2025-12-16 15:30:00
[2025-12-16 10:30:00] [INFO] Time drift: 0.52 seconds
[2025-12-16 10:30:00] [INFO] Time drift is within acceptable range - PASS
[2025-12-16 10:30:00] [INFO] ========== Detection Result: SUCCESS ==========
```

**Remediation Script:** `W32Time-Intune-2025-12-16-10-30.log`
```
[2025-12-16 10:30:05] [INFO] ========== Starting W32Time Configuration ==========
[2025-12-16 10:30:05] [INFO] Computer Name: WORKSTATION01
[2025-12-16 10:30:05] [INFO] Script executed by: SYSTEM
[2025-12-16 10:30:05] [INFO] Setting W32Time service startup type to Automatic
[2025-12-16 10:30:05] [INFO] Service startup type set successfully
[2025-12-16 10:30:05] [INFO] Current W32Time service status: Running
[2025-12-16 10:30:05] [INFO] W32Time service is already running
[2025-12-16 10:30:05] [INFO] Checking W32Time service registration
[2025-12-16 10:30:05] [INFO] W32Time service is already registered
[2025-12-16 10:30:05] [INFO] Configuring NTP servers: 0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org
[2025-12-16 10:30:10] [INFO] NTP configuration result: The command completed successfully.
[2025-12-16 10:30:10] [INFO] Forcing immediate time synchronization
[2025-12-16 10:30:11] [INFO] Resync result: Sending resync command to local computer... The command completed successfully.
[2025-12-16 10:30:11] [INFO] ========== W32Time Configuration Completed Successfully ==========
```

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

## Configuration Customization

### Changing NTP Servers

**Set-W32Time.ps1**:
```powershell
$ntpServers = "0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org"
```

**Detect-W32Time.ps1**:
```powershell
$expectedNtpServers = @("0.ca.pool.ntp.org", "1.ca.pool.ntp.org", "2.ca.pool.ntp.org", "3.ca.pool.ntp.org")
```

### Changing Time Drift Tolerance

**Detect-W32Time.ps1**:
```powershell
$maxDriftSeconds = 300  # 5 minutes
```

### Changing Log Paths

Both scripts use a `$logDir` variable at the top of the script that can be modified:
```powershell
$logDir = "C:\ProgramData\W32Time"
```

### Changing Log Retention

Both scripts use a `$logRetentionDays` variable:
```powershell
$logRetentionDays = 30
```

## Security Considerations

- Scripts run as SYSTEM (elevated) - required for service management
- Log files are written to `C:\ProgramData` (accessible by admins)
- NTP traffic is unencrypted UDP - ensure trusted network path
- Consider using internal NTP servers in high-security environments

## License

This project is provided as-is for use in enterprise environments.

## References

- [Microsoft W32Time Documentation](https://docs.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-top)
- [NTP Pool Project](https://www.ntppool.org/)
- [Intune Remediations](https://docs.microsoft.com/en-us/mem/intune/fundamentals/remediations)
