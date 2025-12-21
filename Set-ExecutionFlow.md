# Set-LazyTime.ps1 Execution Flow

This document describes the step-by-step execution flow of the remediation script.

## Prerequisites

- Script must run with elevated privileges (SYSTEM account via Intune)
- Network connectivity to NTP servers on UDP port 123

## Execution Flow

### 1. Initialization

1. Define configuration variables:
   - Service name: `W32Time`
   - Log directory: `C:\ProgramData\LazyTime`
   - Log path: `C:\ProgramData\LazyTime\Remediate-LazyTime.log`
   - NTP servers: Canadian pool servers (0-3.ca.pool.ntp.org)
   - Log retention: 30 days
   - Max log size: 5 MB
   - Max log archives: 3
   - Geolocation service name: `lfsvc`
   - Registry paths for location policies

2. Define helper functions:
   - `Invoke-LogRotation` - Rotates log file when it exceeds 5 MB, keeps 3 archives
   - `Remove-OldLogs` - Cleans up legacy log files and archives older than retention period

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
     - Rename to `Remediate-LazyTime.log.YYYYMMDD-HHmmss.old`
     - Prune archives beyond 3 most recent

### 4. W32Time Service Configuration

Initialize success flag: `$remediationSuccess = $true`

Start transcript logging to `Remediate-LazyTime.log`

#### 4.1 Set Service Startup Type
1. Log the start of W32Time configuration
2. Set W32Time service startup type to **Automatic**
3. Log success

#### 4.2 Start Service if Stopped
1. Query current W32Time service status
2. If service is not running:
   - Start the service
   - Wait 2 seconds for startup
   - Log new status
3. If service is already running:
   - Log that service is already running

#### 4.3 Check Service Registration
1. Run `w32tm /query /status` to check registration
2. If output contains "not registered" or "service has not been started":
   - Run `w32tm /register` to register the service
   - Log registration result
   - Restart the W32Time service
   - Wait 2 seconds
   - Log new status
3. If service is already registered:
   - Log that registration is complete

#### 4.4 Configure NTP Servers
1. Run `w32tm /config` with parameters:
   - `/manualpeerlist` - Set NTP server list
   - `/syncfromflags:manual` - Use manual peer list
   - `/reliable:yes` - Mark as reliable time source
   - `/update` - Apply changes
2. Log configuration result

#### 4.5 Force Time Synchronization
1. Run `w32tm /resync /force` to force immediate sync
2. Log resync result

#### 4.6 Verify Configuration
1. Run `w32tm /query /status` to get current status
2. Log current W32Time status
3. Run `w32tm /query /peers` to get configured peers
4. Log configured peers

### 5. Geolocation Service Configuration

#### 5.1 Configure LocationAndSensors Registry Policies
1. Check if registry key exists at `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`
2. If key does not exist:
   - Create the registry key
3. Set registry values:
   - `DisableLocation` = 0 (DWORD)
   - `DisableWindowsLocationProvider` = 0 (DWORD)
   - `DisableLocationScripting` = 0 (DWORD)
4. Log each value set

#### 5.2 Configure CapabilityAccessManager Consent
1. Check if registry key exists at `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location`
2. If key does not exist:
   - Create the registry key
3. Set `Value` = "Allow" (String)
4. Log consent value set

#### 5.3 Create lfsvc Service if Missing
1. Query for lfsvc service
2. If service does not exist:
   - Create service using `sc.exe create lfsvc`
   - Configure with svchost.exe binPath
   - Set start type to demand (manual)
   - Log creation result
3. If service exists:
   - Log that service already exists

#### 5.4 Start Geolocation Service
1. Set lfsvc startup type to **Manual**
2. Start the lfsvc service
3. Wait 2 seconds for startup
4. Query and log service status

### 6. Completion

1. Log successful completion message
2. Stop transcript logging
3. Console output and exit:
   - If `$remediationSuccess = $true`:
     - Output "Remediation completed successfully" to stdout
     - Exit with code **0**
   - If `$remediationSuccess = $false`:
     - Output "Remediation failed" to stdout
     - Exit with code **1**

### 7. Error Handling

If any error occurs during execution:
1. Log the error message
2. Log the stack trace
3. Log failure message
4. Set `$remediationSuccess = $false`
5. Stop transcript
6. Output "Remediation failed" to stdout
7. Exit with code **1** (failure)

## Exit Codes

| Code | Output | Meaning |
|------|--------|---------|
| 0 | Remediation completed successfully | All configuration completed successfully |
| 1 | Remediation failed | An error occurred during configuration |

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
Initialize: remediationSuccess = true
  │
  ▼
Start Transcript
  │
  ▼
Set W32Time to Automatic
  │
  ▼
Is W32Time Running? ──No──► Start W32Time Service
  │                              │
  Yes                            │
  │◄─────────────────────────────┘
  ▼
Is W32Time Registered? ──No──► Register W32Time
  │                                  │
  Yes                                ▼
  │                           Restart W32Time
  │◄─────────────────────────────────┘
  ▼
Configure NTP Servers
  │
  ▼
Force Time Resync
  │
  ▼
Query & Log Status
  │
  ▼
Create LocationAndSensors Registry Key (if missing)
  │
  ▼
Set Location Policy Values to 0
  │
  ▼
Create Location Consent Key (if missing)
  │
  ▼
Set Consent Value to "Allow"
  │
  ▼
Does lfsvc Service Exist? ──No──► Create lfsvc Service
  │                                    │
  Yes                                  │
  │◄───────────────────────────────────┘
  ▼
Set lfsvc to Manual & Start
  │
  ▼
Log Completion
  │
  ▼
Stop Transcript
  │
  ▼
Is remediationSuccess = true?
  │
  ├──Yes──► Output "Remediation completed successfully" ──► Exit 0
  │
  └──No───► Output "Remediation failed" ──► Exit 1
```
