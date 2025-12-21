# Detect-LazyTime.ps1 Execution Flow

This document describes the step-by-step execution flow of the detection script.

## Prerequisites

- Script must run with elevated privileges (SYSTEM account via Intune)
- Network connectivity to NTP servers on UDP port 123 (for time drift check)

## Execution Flow

### 1. Initialization

1. Define configuration variables:
   - Service name: `W32Time`
   - Log directory: `C:\ProgramData\LazyTime`
   - Log path: `C:\ProgramData\LazyTime\Detect-LazyTime.log`
   - Expected NTP servers: Canadian pool servers (0-3.ca.pool.ntp.org)
   - Maximum drift: 300 seconds (5 minutes)
   - Log retention: 30 days
   - Max log size: 5 MB
   - Max log archives: 3
   - Geolocation service name: `lfsvc`
   - Registry paths for location policies
   - Expected location policy values (all set to 0)

2. Define helper functions:
   - `Invoke-LogRotation` - Rotates log file when it exceeds 5 MB, keeps 3 archives
   - `Remove-OldLogs` - Cleans up legacy log files and archives older than retention period
   - `Get-NtpTime` - Queries NTP server directly via UDP socket

### 2. Log Directory Setup

1. Check if log directory exists (`C:\ProgramData\LazyTime`)
2. If not, create the directory

### 3. Log Maintenance

1. Call `Remove-OldLogs`:
   - Find legacy log files matching pattern `W32Time-Intune-*.log`
   - Delete any log files older than 30 days
   - Find archive files matching pattern `*.old`
   - Delete any archive files older than 30 days

2. Call `Invoke-LogRotation`:
   - If log file exceeds 5 MB:
     - Rename to `Detect-LazyTime.log.YYYYMMDD-HHmmss.old`
     - Prune archives beyond 3 most recent

### 4. Detection Checks

Initialize detection flag: `$detectionPassed = $true`

Start transcript logging to `Detect-LazyTime.log`

#### Check 1: W32Time Service Status

1. Query W32Time service using `Get-Service`
2. Evaluate result:
   - If service not found: **FAIL** - Log error, set `$detectionPassed = $false`
   - If service not running: **FAIL** - Log error with current status, set `$detectionPassed = $false`
   - If service is running: **PASS** - Log success

#### Check 2: NTP Server Configuration

1. Run `w32tm /query /peers` to get configured peers
2. For each expected NTP server (0-3.ca.pool.ntp.org):
   - Search for server name in configuration output
   - If server not found: Log error for that server
   - If server found: Log success for that server
3. Evaluate overall result:
   - If any server missing: **FAIL** - Log error, set `$detectionPassed = $false`
   - If all servers configured: **PASS** - Log success

#### Check 3: Time Drift Verification

1. Attempt to query NTP time from each server in order:
   - Create UDP socket with 5-second timeout
   - Send NTP request packet (48 bytes, header 0x1B)
   - Receive NTP response
   - Extract timestamp from bytes 40-47
   - Convert NTP timestamp to DateTime (epoch: 1900-01-01)
   - If successful, log server used and stop trying other servers
   - If failed, log warning and try next server

2. Evaluate result:
   - If no NTP server responded: **FAIL** - Log error, set `$detectionPassed = $false`
   - If NTP time received:
     - Get local system time (UTC)
     - Calculate absolute difference in seconds
     - Log both times and drift value
     - If drift > 300 seconds: **FAIL** - Log error, set `$detectionPassed = $false`
     - If drift <= 300 seconds: **PASS** - Log success

#### Check 4: Geolocation Service Status

1. Query lfsvc service using `Get-Service`
2. Evaluate result:
   - If service not found: **FAIL** - Log error, set `$detectionPassed = $false`
   - If service not running: **FAIL** - Log error with current status, set `$detectionPassed = $false`
   - If service is running: **PASS** - Log success

#### Check 5: LocationAndSensors Registry Policies

1. Check if registry key exists at `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`
2. If key not found: **FAIL** - Log error, set `$detectionPassed = $false`
3. If key exists, check each policy value:
   - `DisableLocation` - Must equal 0
   - `DisableWindowsLocationProvider` - Must equal 0
   - `DisableLocationScripting` - Must equal 0
4. For each value:
   - If value not found: Log error
   - If value incorrect: Log error with actual vs expected
   - If value correct: Log success
5. Evaluate overall result:
   - If any policy incorrect: **FAIL** - Log error, set `$detectionPassed = $false`
   - If all policies correct: **PASS** - Log success

#### Check 6: CapabilityAccessManager Location Consent

1. Check if registry key exists at `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location`
2. If key not found: **FAIL** - Log error, set `$detectionPassed = $false`
3. If key exists:
   - Read `Value` property
   - If property not found: **FAIL** - Log error, set `$detectionPassed = $false`
   - If value is not "Allow": **FAIL** - Log error with actual value, set `$detectionPassed = $false`
   - If value is "Allow": **PASS** - Log success

### 5. Final Result

1. Log detection result to transcript:
   - If `$detectionPassed = $true`: Log "Detection Result: COMPLIANT"
   - If `$detectionPassed = $false`: Log "Detection Result: NON-COMPLIANT"

2. Stop transcript logging

3. Console output and exit:
   - If `$detectionPassed = $true`:
     - Output "Compliant" to stdout
     - Exit with code **0**
   - If `$detectionPassed = $false`:
     - Output "Non-Compliant" to stdout
     - Exit with code **1**

### 6. Error Handling

If any unexpected error occurs during execution:
1. Log the error message
2. Log "Detection Result: FAILED"
3. Set `$detectionPassed = $false`
4. Stop transcript
5. Output "Non-Compliant" to stdout
6. Exit with code **1** (failure)

## Exit Codes

| Code | Output | Meaning |
|------|--------|---------|
| 0 | Compliant | All six checks passed - device is compliant |
| 1 | Non-Compliant | One or more checks failed - remediation required |

## Detection Summary

| Check | What It Verifies | Failure Triggers Remediation |
|-------|------------------|------------------------------|
| 1 | W32Time service is running | Yes |
| 2 | All 4 NTP servers are configured | Yes |
| 3 | Time drift is within 300 seconds | Yes |
| 4 | lfsvc service is running | Yes |
| 5 | Location policies allow location services | Yes |
| 6 | Location consent is set to "Allow" | Yes |

## Flowchart

```
START
  │
  ▼
Create Log Directory (if missing)
  │
  ▼
Remove Old Logs (30+ days)
  │
  ▼
Rotate Log File (if > 5 MB)
  │
  ▼
Start Transcript
  │
  ▼
Initialize: detectionPassed = true
  │
  ▼
┌─────────────────────────────────────┐
│ CHECK 1: W32Time Service Status     │
│                                     │
│ Is service found and running?       │
│   No  ──► detectionPassed = false   │
│   Yes ──► Log PASS                  │
└─────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────┐
│ CHECK 2: NTP Configuration          │
│                                     │
│ Are all 4 NTP servers configured?   │
│   No  ──► detectionPassed = false   │
│   Yes ──► Log PASS                  │
└─────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────┐
│ CHECK 3: Time Drift                 │
│                                     │
│ Query NTP server directly via UDP   │
│ Calculate drift from local time     │
│                                     │
│ Is drift <= 300 seconds?            │
│   No  ──► detectionPassed = false   │
│   Yes ──► Log PASS                  │
└─────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────┐
│ CHECK 4: lfsvc Service Status       │
│                                     │
│ Is service found and running?       │
│   No  ──► detectionPassed = false   │
│   Yes ──► Log PASS                  │
└─────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────┐
│ CHECK 5: Location Registry Policies │
│                                     │
│ Are all 3 values set to 0?          │
│   No  ──► detectionPassed = false   │
│   Yes ──► Log PASS                  │
└─────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────┐
│ CHECK 6: Location Consent           │
│                                     │
│ Is consent Value = "Allow"?         │
│   No  ──► detectionPassed = false   │
│   Yes ──► Log PASS                  │
└─────────────────────────────────────┘
  │
  ▼
Log Detection Result
  │
  ▼
Stop Transcript
  │
  ▼
Is detectionPassed = true?
  │
  ├──Yes──► Output "Compliant" ──► Exit 0
  │
  └──No───► Output "Non-Compliant" ──► Exit 1
```
