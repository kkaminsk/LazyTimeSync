# Set-LazyW32TimeandLocationServices.ps1 Execution Flow

This document describes the step-by-step execution flow of the remediation script.

## Prerequisites

- Script must run with elevated privileges (SYSTEM account via Intune)
- Network connectivity to NTP servers on UDP port 123

## Execution Flow

### 1. Initialization

1. Define configuration variables:
   - Service name: `W32Time`
   - Log directory: `C:\ProgramData\LazyW32TimeandLoc`
   - NTP servers: Canadian pool servers (0-3.ca.pool.ntp.org)
   - Log retention: 30 days
   - Geolocation service name: `lfsvc`
   - Registry paths for location policies

2. Define helper functions:
   - `Remove-OldLogs` - Cleans up log files older than retention period
   - `Write-Log` - Writes timestamped entries to log file

### 2. Log Cleanup

1. Check if log directory exists
2. Find all log files matching pattern `W32Time-Intune-*.log`
3. Delete any log files older than 30 days

### 3. W32Time Service Configuration

#### 3.1 Set Service Startup Type
1. Log the start of W32Time configuration
2. Set W32Time service startup type to **Automatic**
3. Log success

#### 3.2 Start Service if Stopped
1. Query current W32Time service status
2. If service is not running:
   - Start the service
   - Wait 2 seconds for startup
   - Log new status
3. If service is already running:
   - Log that service is already running

#### 3.3 Check Service Registration
1. Run `w32tm /query /status` to check registration
2. If service is not registered or not started:
   - Run `w32tm /register` to register the service
   - Log registration result
   - Restart the W32Time service
   - Wait 2 seconds
   - Log new status
3. If service is already registered:
   - Log that registration is complete

#### 3.4 Configure NTP Servers
1. Run `w32tm /config` with parameters:
   - `/manualpeerlist` - Set NTP server list
   - `/syncfromflags:manual` - Use manual peer list
   - `/reliable:yes` - Mark as reliable time source
   - `/update` - Apply changes
2. Log configuration result

#### 3.5 Force Time Synchronization
1. Run `w32tm /resync /force` to force immediate sync
2. Log resync result

#### 3.6 Verify Configuration
1. Run `w32tm /query /status` to get current status
2. Log current W32Time status
3. Run `w32tm /query /peers` to get configured peers
4. Log configured peers

### 4. Geolocation Service Configuration

#### 4.1 Configure LocationAndSensors Registry Policies
1. Check if registry key exists at `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`
2. If key does not exist:
   - Create the registry key
3. Set registry values:
   - `DisableLocation` = 0 (DWORD)
   - `DisableWindowsLocationProvider` = 0 (DWORD)
   - `DisableLocationScripting` = 0 (DWORD)
4. Log each value set

#### 4.2 Configure CapabilityAccessManager Consent
1. Check if registry key exists at `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location`
2. If key does not exist:
   - Create the registry key
3. Set `Value` = "Allow" (String)
4. Log consent value set

#### 4.3 Create lfsvc Service if Missing
1. Query for lfsvc service
2. If service does not exist:
   - Create service using `sc.exe create lfsvc`
   - Configure with svchost.exe binPath
   - Set start type to demand (manual)
   - Log creation result
3. If service exists:
   - Log that service already exists

#### 4.4 Start Geolocation Service
1. Set lfsvc startup type to **Manual**
2. Start the lfsvc service
3. Wait 2 seconds for startup
4. Query and log service status

### 5. Completion

1. Log successful completion message
2. Exit with code **0** (success)

### 6. Error Handling

If any error occurs during execution:
1. Log the error message
2. Log the stack trace
3. Log failure message
4. Exit with code **1** (failure)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All configuration completed successfully |
| 1 | An error occurred during configuration |

## Flowchart

```
START
  │
  ▼
Remove Old Logs
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
Exit 0 (Success)
```
