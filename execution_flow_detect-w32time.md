# Execution Flow: Detect-W32Time.ps1

This document describes the execution flow of the W32Time detection script in plain English.

## Overview

This script checks whether the Windows Time service (W32Time) is properly configured and functioning. It performs three compliance checks and reports the result to Intune. If any check fails, the remediation script will be triggered.

---

## Execution Flow

### 1. Initialize Variables

The script begins by setting up configuration values:

- **Service name**: W32Time
- **Log directory**: `C:\ProgramData\W32Time`
- **Log file**: Creates a timestamped filename (e.g., `W32Time-Intune-2025-12-16-10-30.log`)
- **Expected NTP servers**: Array of four Canadian pool servers (0-3.ca.pool.ntp.org)
- **Maximum drift**: 300 seconds (5 minutes)
- **Log retention**: 30 days

### 2. Clean Up Old Logs

Before any other operations, the script removes stale log files:

1. Check if the log directory exists
2. Calculate the cutoff date (current date minus 30 days)
3. Find all files matching `W32Time-Intune-*.log`
4. Delete any files with a last modified date older than the cutoff
5. Errors during cleanup are silently ignored to prevent blocking detection

### 3. Log Script Start

The script logs:

- A header indicating the detection process is starting
- The computer name (for identification in centralized logging)
- Initializes the `$detectionPassed` flag to `$true`

### 4. Check 1: Service Status

Verify the W32Time service is running:

1. Attempt to get the W32Time service object
2. **If service is not found:**
   - Log an error
   - Set `$detectionPassed` to `$false`
3. **If service exists but is not running:**
   - Log the current status as an error
   - Set `$detectionPassed` to `$false`
4. **If service is running:**
   - Log success (PASS)

### 5. Check 2: NTP Server Configuration

Verify all expected NTP servers are configured:

1. Run `w32tm /query /peers` to get the current peer configuration
2. Initialize `$allServersConfigured` flag to `$true`
3. Loop through each expected NTP server:
   - Search for the server name in the peer configuration output
   - **If server is not found:**
     - Log an error for that specific server
     - Set `$allServersConfigured` to `$false`
   - **If server is found:**
     - Log success (PASS) for that server
4. After checking all servers:
   - **If any server was missing:**
     - Log an error summary
     - Set `$detectionPassed` to `$false`
   - **If all servers were found:**
     - Log overall success (PASS)

### 6. Check 3: Time Drift

Verify the local system time is accurate:

#### 6a. Query NTP Time

1. Initialize variables for NTP time and tested server
2. Loop through each expected NTP server:
   - Log the query attempt
   - Call the `Get-NtpTime` function (see below)
   - **If time was retrieved successfully:**
     - Store the server name and NTP time
     - Log success
     - Exit the loop (only need one successful response)
   - **If query failed:**
     - Log a warning
     - Continue to the next server

#### 6b. Calculate and Evaluate Drift

1. **If no NTP server responded:**
   - Log an error
   - Set `$detectionPassed` to `$false`
2. **If NTP time was retrieved:**
   - Get the current local UTC time
   - Calculate the absolute difference in seconds
   - Log both timestamps and the drift value
   - **If drift exceeds 300 seconds:**
     - Log an error with the drift value
     - Set `$detectionPassed` to `$false`
   - **If drift is within range:**
     - Log success (PASS)

### 7. Final Result

Evaluate the overall detection result:

1. **If `$detectionPassed` is still `$true`:**
   - Log success message
   - Output "Compliant" to stdout
   - Exit with code **0**
2. **If `$detectionPassed` is `$false`:**
   - Log failure message
   - Output "Non-Compliant" to stdout
   - Exit with code **1**

---

## Helper Function: Get-NtpTime

This function queries an NTP server directly via UDP:

1. Create a 48-byte array for the NTP packet
2. Set byte 0 to `0x1B` (NTP version 3, client mode)
3. Create a UDP socket with 5-second timeouts
4. Connect to the NTP server on port 123
5. Send the request packet
6. Receive the response packet
7. Close the socket
8. Extract the timestamp from bytes 40-47 of the response:
   - Bytes 40-43: Integer part (seconds since 1900-01-01)
   - Bytes 44-47: Fractional part
9. Convert to a DateTime object and return
10. **If any error occurs:** Return `$null`

---

## Error Handling

If any unexpected exception occurs:

1. Log the error message
2. Log a failure message
3. Output "Non-Compliant" to stdout
4. Exit with code **1**

This ensures Intune triggers remediation even on unexpected failures.

---

## Flow Diagram

```
┌─────────────────────────────────┐
│         Script Start            │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│    Initialize Variables         │
│   Set detectionPassed = true    │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│     Remove Old Log Files        │
│      (older than 30 days)       │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│      Log Script Start           │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  CHECK 1: Service Status        │
│   Is W32Time running?           │
└─────────────┬───────────────────┘
              │
       ┌──────┴──────┐
       │             │
      No            Yes
       │             │
       ▼             │
┌──────────────┐     │
│ Log ERROR    │     │
│ Flag = false │     │
└──────┬───────┘     │
       │             │
       └──────┬──────┘
              │
              ▼
┌─────────────────────────────────┐
│  CHECK 2: NTP Configuration     │
│  Are all 4 servers configured?  │
└─────────────┬───────────────────┘
              │
       ┌──────┴──────┐
       │             │
      No            Yes
       │             │
       ▼             │
┌──────────────┐     │
│ Log ERROR    │     │
│ Flag = false │     │
└──────┬───────┘     │
       │             │
       └──────┬──────┘
              │
              ▼
┌─────────────────────────────────┐
│  CHECK 3: Time Drift            │
│  Query NTP server for time      │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│   Try each NTP server until     │
│   one responds successfully     │
└─────────────┬───────────────────┘
              │
       ┌──────┴──────┐
       │             │
    None           Got Time
   Responded         │
       │             │
       ▼             ▼
┌──────────────┐ ┌──────────────────┐
│ Log ERROR    │ │ Calculate drift  │
│ Flag = false │ │ Local vs NTP     │
└──────┬───────┘ └────────┬─────────┘
       │                  │
       │           ┌──────┴──────┐
       │           │             │
       │       > 300 sec    <= 300 sec
       │           │             │
       │           ▼             │
       │    ┌──────────────┐     │
       │    │ Log ERROR    │     │
       │    │ Flag = false │     │
       │    └──────┬───────┘     │
       │           │             │
       └─────┬─────┴─────────────┘
             │
             ▼
┌─────────────────────────────────┐
│   Evaluate detectionPassed      │
└─────────────┬───────────────────┘
              │
       ┌──────┴──────┐
       │             │
     false         true
       │             │
       ▼             ▼
┌──────────────┐ ┌──────────────┐
│ Output:      │ │ Output:      │
│"Non-Compliant"│ │ "Compliant"  │
│ Exit code 1  │ │ Exit code 0  │
└──────────────┘ └──────────────┘
```

---

## Compliance Checks Summary

| Check | What It Verifies | Pass Condition | Fail Condition |
|-------|------------------|----------------|----------------|
| 1 | Service Status | W32Time service is running | Service missing or stopped |
| 2 | NTP Configuration | All 4 expected servers are configured | Any server missing |
| 3 | Time Drift | Local time within 300 seconds of NTP | Drift exceeds 300 seconds or no NTP response |

---

## Exit Codes

| Code | Output | Meaning | Intune Action |
|------|--------|---------|---------------|
| 0 | Compliant | All checks passed | No action needed |
| 1 | Non-Compliant | One or more checks failed | Run remediation script |
