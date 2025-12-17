# Test-NTP.ps1 Execution Flow

This document describes the step-by-step execution flow of the pre-deployment NTP connectivity test script.

## Purpose

This script verifies that outbound NTP connectivity is working before deploying the W32Time remediation scripts. It helps identify firewall or network issues that would prevent time synchronization.

## Prerequisites

- PowerShell 5.1 or later
- Administrator privileges recommended
- Network access to test NTP connectivity

## Execution Flow

### 1. Initialization

1. Define configuration variables:
   - NTP servers to test: Canadian pool servers (0-3.ca.pool.ntp.org)
   - Samples per server: 3
   - Initialize empty results array

2. Display header:
   - Print "NTP Connectivity Test" banner
   - Indicate testing UDP port 123

### 2. Server Testing Loop

For each NTP server in the list, perform the following:

#### 2.1 Display Current Server
1. Print server name being tested

#### 2.2 DNS Resolution Test
1. Attempt to resolve server hostname to IP address using `[System.Net.Dns]::GetHostAddresses()`
2. Evaluate result:
   - If successful:
     - Display resolved IP address
     - Continue to NTP query test
   - If failed:
     - Display "DNS resolution FAILED"
     - Record FAIL result with details
     - Skip to next server (do not attempt NTP query)

#### 2.3 NTP Query Test
1. Execute `w32tm /stripchart` command with parameters:
   - `/computer:<server>` - Target NTP server
   - `/samples:3` - Number of time samples to collect
   - `/dataonly` - Output data only (no chart)

2. Capture command output

3. Check for error conditions in output:
   - Look for "error", "0x800705B4", or "timed out" patterns

4. Evaluate result:
   - If error pattern found:
     - Display "NTP query FAILED"
     - Display "Connection timed out or blocked"
     - Record FAIL result with firewall recommendation
   - If no error pattern:
     - Attempt to extract time offset from output using regex
     - If offset found:
       - Display "NTP query SUCCESS" with offset value
       - Record PASS result with offset details
     - If offset not found:
       - Display "NTP query SUCCESS"
       - Record PASS result with generic success message

5. Handle unexpected exceptions:
   - Display error message
   - Record FAIL result with exception details

### 3. Results Summary

#### 3.1 Display Results Table
1. Print "Test Results Summary" header
2. Display all results in formatted table showing:
   - Server name
   - Status (PASS/FAIL)
   - Details

#### 3.2 Calculate Statistics
1. Count servers with PASS status
2. Count servers with FAIL status

#### 3.3 Display Pass Count
1. Print "Passed: X / Y"
2. Color coding:
   - Green if all passed
   - Yellow if any failed

### 4. Final Result

#### If Any Tests Failed (failed > 0):
1. Print "Failed: X / Y" in red
2. Print recommendation: "Ensure UDP port 123 is open outbound to NTP servers"
3. Print firewall rule suggestion: "UDP 123 Outbound to *.pool.ntp.org"
4. Exit with code **1** (failure)

#### If All Tests Passed (failed = 0):
1. Print "All NTP servers are reachable. Safe to deploy W32Time scripts."
2. Exit with code **0** (success)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All NTP servers are reachable - safe to deploy |
| 1 | One or more servers unreachable - check firewall settings |

## Test Results

| Status | Meaning |
|--------|---------|
| PASS | DNS resolved and NTP query successful |
| FAIL (DNS) | Could not resolve server hostname |
| FAIL (Timeout) | DNS resolved but NTP query timed out (firewall likely blocking UDP 123) |
| FAIL (Error) | Unexpected error during NTP query |

## Sample Output

### Successful Test
```
========== NTP Connectivity Test ==========
Testing outbound UDP port 123 to NTP servers

Testing: 0.ca.pool.ntp.org
  DNS resolved to: 162.159.200.1
  NTP query SUCCESS (offset: +0.0234512s)

Testing: 1.ca.pool.ntp.org
  DNS resolved to: 198.60.22.240
  NTP query SUCCESS (offset: -0.0156234s)

Testing: 2.ca.pool.ntp.org
  DNS resolved to: 192.139.160.5
  NTP query SUCCESS (offset: +0.0089123s)

Testing: 3.ca.pool.ntp.org
  DNS resolved to: 206.108.0.133
  NTP query SUCCESS (offset: -0.0045678s)

========== Test Results Summary ==========

Server            Status Details
------            ------ -------
0.ca.pool.ntp.org PASS   Offset: +0.0234512s
1.ca.pool.ntp.org PASS   Offset: -0.0156234s
2.ca.pool.ntp.org PASS   Offset: +0.0089123s
3.ca.pool.ntp.org PASS   Offset: -0.0045678s

Passed: 4 / 4

All NTP servers are reachable. Safe to deploy W32Time scripts.
```

### Failed Test (Firewall Blocking)
```
========== NTP Connectivity Test ==========
Testing outbound UDP port 123 to NTP servers

Testing: 0.ca.pool.ntp.org
  DNS resolved to: 162.159.200.1
  NTP query FAILED
  Error: Connection timed out or blocked

...

========== Test Results Summary ==========

Server            Status Details
------            ------ -------
0.ca.pool.ntp.org FAIL   Connection timed out - check firewall UDP 123
...

Passed: 0 / 4
Failed: 4 / 4

Recommendation: Ensure UDP port 123 is open outbound to NTP servers.
Firewall rule needed: UDP 123 Outbound to *.pool.ntp.org
```

## Flowchart

```
START
  │
  ▼
Display Header
  │
  ▼
Initialize results = []
  │
  ▼
┌─────────────────────────────────────────┐
│ FOR EACH server IN ntpServers           │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │ DNS Resolution                  │   │
│   │                                 │   │
│   │ Can resolve hostname?           │   │
│   │   No ──► Record FAIL            │   │
│   │          Continue to next       │   │
│   │   Yes ──► Display IP            │   │
│   └─────────────────────────────────┘   │
│                 │                       │
│                 ▼                       │
│   ┌─────────────────────────────────┐   │
│   │ NTP Query via w32tm             │   │
│   │                                 │   │
│   │ Run w32tm /stripchart           │   │
│   │                                 │   │
│   │ Error in output?                │   │
│   │   Yes ──► Record FAIL           │   │
│   │   No  ──► Record PASS           │   │
│   │           Extract offset        │   │
│   └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
  │
  ▼
Display Results Table
  │
  ▼
Count PASS and FAIL
  │
  ▼
Display "Passed: X / Y"
  │
  ▼
Any failures?
  │
  ├──Yes──► Display "Failed: X / Y"
  │         Display firewall recommendation
  │         Exit 1
  │
  └──No───► Display "Safe to deploy"
            Exit 0
```

## Troubleshooting

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| DNS resolution failed | No DNS connectivity or server down | Check DNS settings, try nslookup manually |
| Connection timed out | Firewall blocking UDP 123 | Add outbound firewall rule for UDP 123 |
| All servers fail | Network-wide NTP block | Contact network administrator |
| Partial failures | Specific server issues | May still work with available servers |
