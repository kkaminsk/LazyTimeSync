# Execution Flow: Set-W32Time.ps1

This document describes the execution flow of the W32Time remediation script in plain English.

## Overview

This script configures the Windows Time service (W32Time) to synchronize with Canadian NTP pool servers. It runs as SYSTEM via Intune when the detection script reports non-compliance.

---

## Execution Flow

### 1. Initialize Variables

The script begins by setting up configuration values:

- **Service name**: W32Time
- **Log directory**: `C:\ProgramData\W32Time`
- **Log file**: Creates a timestamped filename (e.g., `W32Time-Intune-2025-12-16-10-30.log`)
- **NTP servers**: Four Canadian pool servers (0-3.ca.pool.ntp.org)
- **Log retention**: 30 days

### 2. Clean Up Old Logs

Before any other operations, the script removes stale log files:

1. Check if the log directory exists
2. Calculate the cutoff date (current date minus 30 days)
3. Find all files matching `W32Time-Intune-*.log`
4. Delete any files with a last modified date older than the cutoff
5. Errors during cleanup are silently ignored to prevent blocking the main script

### 3. Log Script Start

The script logs:

- A header indicating the configuration process is starting
- The computer name (for identification in centralized logging)
- The user context running the script (typically SYSTEM)

### 4. Configure Service Startup Type

1. Set the W32Time service startup type to **Automatic**
2. This ensures the service starts automatically when Windows boots
3. Log the result

### 5. Start the Service (If Needed)

1. Check the current status of the W32Time service
2. Log the current status
3. **If the service is not running:**
   - Attempt to start the service
   - Wait 2 seconds for the service to initialize
   - Check and log the new status
4. **If the service is already running:**
   - Log that no action was needed

### 6. Configure NTP Servers

1. Run the `w32tm /config` command with the following options:
   - `/manualpeerlist`: Set the list of NTP servers to use
   - `/syncfromflags:manual`: Tell the service to sync from the manual peer list
   - `/reliable:yes`: Mark this machine as a reliable time source
   - `/update`: Apply the configuration changes immediately
2. Log the result of the configuration command

### 7. Force Time Synchronization

1. Run `w32tm /resync /force` to immediately synchronize the clock
2. The `/force` flag ensures sync happens even if the time difference is small
3. Log the result of the resync command

### 8. Verify Configuration

Query and log the current state for verification:

1. Run `w32tm /query /status` to get the current synchronization status
2. Run `w32tm /query /peers` to confirm the NTP servers are configured
3. Log both results for troubleshooting purposes

### 9. Exit Successfully

1. Log a success message indicating configuration completed
2. Exit with code **0** (success)

---

## Error Handling

If any step throws an exception:

1. Log the error message
2. Log the stack trace for debugging
3. Log a failure message
4. Exit with code **1** (failure)

This triggers Intune to report the remediation as failed.

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
│  (service name, log path, NTP)  │
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
│  (computer name, user context)  │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Set Service Startup Type       │
│       to Automatic              │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│   Is Service Running?           │
└─────────────┬───────────────────┘
              │
       ┌──────┴──────┐
       │             │
      No            Yes
       │             │
       ▼             │
┌──────────────┐     │
│Start Service │     │
│ Wait 2 sec   │     │
└──────┬───────┘     │
       │             │
       └──────┬──────┘
              │
              ▼
┌─────────────────────────────────┐
│    Configure NTP Servers        │
│  (w32tm /config /manualpeerlist)│
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│   Force Time Synchronization    │
│      (w32tm /resync /force)     │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│    Query & Log Status           │
│  (verify configuration applied) │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│         Exit Code 0             │
│          (Success)              │
└─────────────────────────────────┘
```

---

## Exit Codes

| Code | Meaning | Intune Result |
|------|---------|---------------|
| 0 | All operations completed successfully | Remediation succeeded |
| 1 | An error occurred during execution | Remediation failed |
