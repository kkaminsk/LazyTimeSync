# Intune Remediation Script Best Practices

Reference for building detection and remediation scripts for Microsoft Intune.

## Core Architecture

### Dual-Script Model
- **Detection Script**: Lightweight sensor that checks compliance state
- **Remediation Script**: Executes only when detection returns non-compliant

### Execution Flow
1. Detection script runs
2. If Exit 1 → Remediation script runs
3. Detection script runs again (verification)
4. Final status reported to Intune

## Exit Code Requirements

| Exit Code | Meaning | Intune Behavior |
|-----------|---------|-----------------|
| `0` | Compliant/Success | Skip remediation, report "Without Issues" |
| `1` | Non-Compliant | Trigger remediation, report "With Issues" |
| Other | Script Error | Report "Failed" |

**Critical**: Every code path must explicitly call `Exit 0` or `Exit 1`. Never let scripts end without an exit code.

## Script Patterns

### Detection Script Template

```powershell
<#
.SYNOPSIS
    Detection script for [Component]
.DESCRIPTION
    Returns Exit 0 if compliant, Exit 1 if remediation needed
#>

# --- CONFIGURATION ---
$LogDir = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogDir\Detect_ComponentName.log"

# --- LOGGING SETUP ---
try {
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    Start-Transcript -Path $LogFile -Append -Force -ErrorAction SilentlyContinue

    # --- DETECTION LOGIC ---
    # Check 1: Verify condition exists
    if (-not (Test-Path "HKLM:\SOFTWARE\Expected\Path")) {
        Write-Output "Non-Compliant: Registry path missing"
        Exit 1
    }

    # Check 2: Verify value matches
    $current = Get-ItemProperty -Path "HKLM:\SOFTWARE\Expected\Path" -Name "Setting" -ErrorAction SilentlyContinue
    if ($null -eq $current -or $current.Setting -ne $expectedValue) {
        Write-Output "Non-Compliant: Value mismatch"
        Exit 1
    }

    # All checks passed
    Write-Output "Compliant: All checks passed"
    Exit 0

} catch {
    Write-Output "Error: $($_.Exception.Message)"
    Exit 1  # Fail-safe to non-compliant
} finally {
    Stop-Transcript
}
```

### Remediation Script Template

```powershell
<#
.SYNOPSIS
    Remediation script for [Component]
.DESCRIPTION
    Applies fix for non-compliant state detected
#>

# --- CONFIGURATION ---
$LogDir = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogDir\Remediate_ComponentName.log"

# --- LOGGING SETUP ---
try {
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    Start-Transcript -Path $LogFile -Append -Force -ErrorAction SilentlyContinue

    Write-Output "$(Get-Date): Starting remediation"

    # --- REMEDIATION LOGIC ---
    # Create path if missing
    if (-not (Test-Path "HKLM:\SOFTWARE\Expected\Path")) {
        New-Item -Path "HKLM:\SOFTWARE\Expected\Path" -Force | Out-Null
    }

    # Set value
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Expected\Path" -Name "Setting" -Value $expectedValue -Force

    Write-Output "Remediation completed successfully"
    Exit 0

} catch {
    Write-Output "Error: $($_.Exception.Message)"
    Exit 1
} finally {
    Stop-Transcript
}
```

## Logging Requirements

### Log Location
Always use: `$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\`

This is the standard IME log directory. Support engineers know to look here, and "Collect Diagnostics" in Intune automatically uploads from this location.

### Log Rotation
Scripts must manage their own log file sizes. The IME does not rotate custom logs.

```powershell
function Invoke-LogRotation {
    param (
        [string]$Path,
        [int]$MaxSizeMB = 5,
        [int]$MaxHistory = 3
    )

    if (Test-Path $Path) {
        $file = Get-Item $Path
        if ($file.Length -gt ($MaxSizeMB * 1MB)) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $archive = "$Path.$timestamp.old"
            Rename-Item -Path $Path -NewName $archive -Force

            # Prune old archives
            $oldLogs = Get-ChildItem -Path (Split-Path $Path) -Filter "*.old" |
                       Sort-Object LastWriteTime -Descending
            if ($oldLogs.Count -gt $MaxHistory) {
                $oldLogs | Select-Object -Skip $MaxHistory | Remove-Item -Force
            }
        }
    }
}
```

### Use Start-Transcript
Always wrap script execution with `Start-Transcript` / `Stop-Transcript` for complete activity capture.

## Console Output Rules

### Character Limit
Intune truncates output at **2,048 characters**. Keep console output concise.

### Output Strategy
- Reserve `Write-Output` for high-level status messages
- Write detailed logs to local file
- Final output should be a single, clear status message

```powershell
# Good: Concise status
Write-Output "Compliant: W32Time running, NTP configured correctly"

# Bad: Verbose dump that may get truncated
Write-Output "Checking service... Service found... Checking config..."
```

### JSON for Automation
For Graph API consumption, output JSON:

```powershell
$status = @{
    State = "NonCompliant"
    Reason = "Service stopped"
    Timestamp = (Get-Date -Format "o")
}
Write-Output ($status | ConvertTo-Json -Compress)
Exit 1
```

## Execution Context

### System Context (Default)
- Full local admin rights
- Access to HKLM registry
- Can manage services and install software
- No network resources authenticated by user
- No UI visible to user

### User Context
- Runs as logged-on user
- Access to HKCU registry
- User's network permissions
- Fails if no user logged in

**Never use**: `Read-Host`, message boxes, or any UI prompts. Scripts run headless and will hang.

## Error Handling

### Wrap All Actions
Every significant operation needs try/catch:

```powershell
try {
    Set-Service -Name "W32Time" -StartupType Automatic -ErrorAction Stop
    Start-Service -Name "W32Time" -ErrorAction Stop
} catch {
    Write-Output "Failed to configure service: $($_.Exception.Message)"
    Exit 1
}
```

### Fail-Safe to Non-Compliant
If detection script crashes, return Exit 1. This ensures visibility rather than silent failure.

## Design Principles

### Idempotency
Scripts must be safe to run multiple times:
- Use `-Force` on New-Item, Set-ItemProperty
- Check existence before create operations
- Don't error on "already exists" conditions

### Minimalism
Remediation should fix only the specific issue detected:
- No reboots unless absolutely required
- No extra "cleanup" or "optimization"
- No changes beyond scope

### No User Interaction
- No Read-Host
- No popup dialogs
- No confirmation prompts

### No Hardcoded Secrets
Scripts are cached locally and readable by admins. Never embed:
- Passwords
- API keys
- Certificates with private keys

## Avoid Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Missing exit codes | Undefined behavior | Explicit Exit 0/1 on all paths |
| Verbose console output | Truncation loses errors | Single status message, detailed local log |
| No error handling | Silent failures | Wrap in try/catch |
| UI prompts | Script hangs indefinitely | Remove all interactive elements |
| Growing log files | Disk exhaustion | Implement log rotation |
| Hardcoded credentials | Security vulnerability | Use certificates or managed identity |

## Pre-Deployment Checklist

- [ ] Detection returns Exit 0 when compliant
- [ ] Detection returns Exit 1 when non-compliant
- [ ] Remediation fixes the exact issue detected
- [ ] Both scripts have try/catch/finally blocks
- [ ] Logging writes to IME log directory
- [ ] Log rotation implemented
- [ ] Console output under 2,048 characters
- [ ] No interactive prompts
- [ ] No hardcoded secrets
- [ ] Tested in System context
