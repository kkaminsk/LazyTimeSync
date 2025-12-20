# Intune Remediation Script Rules

Instructions for building detection and remediation scripts for Microsoft Intune.

## Required Reading

Before writing any Intune scripts, read:
- `@/Rules/bestpractices.md` - Core patterns and requirements
- `@/Rules/Intune PowerShell Remediation Best Practices.md` - Comprehensive reference

## Script Requirements

### Detection Scripts

1. **Must return explicit exit codes**
   - `Exit 0` = Compliant (skip remediation)
   - `Exit 1` = Non-Compliant (trigger remediation)

2. **Must be deterministic** - Same input always produces same output

3. **Must be idempotent** - Running multiple times doesn't change state

4. **Structure**:
   ```powershell
   try {
       Start-Transcript -Path $LogFile -Append -Force -ErrorAction SilentlyContinue
       # Detection checks here
       # Exit 0 or Exit 1 on every path
   } catch {
       Exit 1  # Fail-safe to non-compliant
   } finally {
       Stop-Transcript
   }
   ```

### Remediation Scripts

1. **Fix only what detection found** - No extra cleanup or optimization

2. **Must be idempotent** - Use `-Force` flags, check before create

3. **No reboots** unless absolutely required

4. **No user interaction** - No Read-Host, no popups

## Logging Standards

- **Path**: `$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\`
- **Always use**: `Start-Transcript` / `Stop-Transcript`
- **Implement log rotation** - IME does not rotate custom logs

## Console Output

- **Limit**: 2,048 characters (truncated after)
- **Keep concise**: Single status message for Intune console
- **Detailed logs**: Write to local file, not console

## Execution Context

Scripts run as **SYSTEM** by default:
- Full local admin rights
- No user session access
- No network resources authenticated by user
- **No UI visible** - never use interactive prompts

## Common Patterns

### Registry Check (Detection)
```powershell
$path = "HKLM:\SOFTWARE\Policies\Example"
$name = "Setting"
$expected = 1

if (-not (Test-Path $path)) {
    Write-Output "Non-Compliant: Path missing"
    Exit 1
}

$current = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
if ($null -eq $current -or $current.$name -ne $expected) {
    Write-Output "Non-Compliant: Value mismatch"
    Exit 1
}

Write-Output "Compliant"
Exit 0
```

### Registry Fix (Remediation)
```powershell
$path = "HKLM:\SOFTWARE\Policies\Example"
$name = "Setting"
$value = 1

if (-not (Test-Path $path)) {
    New-Item -Path $path -Force | Out-Null
}
Set-ItemProperty -Path $path -Name $name -Value $value -Force
Write-Output "Applied setting"
Exit 0
```

### Service Check (Detection)
```powershell
$service = Get-Service -Name "ServiceName" -ErrorAction SilentlyContinue
if ($null -eq $service -or $service.Status -ne 'Running') {
    Write-Output "Non-Compliant: Service not running"
    Exit 1
}
Write-Output "Compliant: Service running"
Exit 0
```

### Service Fix (Remediation)
```powershell
Set-Service -Name "ServiceName" -StartupType Automatic -ErrorAction Stop
Start-Service -Name "ServiceName" -ErrorAction Stop
Write-Output "Service started"
Exit 0
```

## Security Rules

- **Never hardcode secrets** (passwords, API keys)
- **No PII in console output** - visible to Intune Reader role
- **Validate downloads** - Check file hash before execution
- **Use HTTPS** for any external resources

## Checklist Before Commit

- [ ] Exit 0 when compliant
- [ ] Exit 1 when non-compliant
- [ ] Try/catch/finally structure
- [ ] Start-Transcript logging
- [ ] Console output under 2,048 chars
- [ ] No interactive prompts
- [ ] No hardcoded secrets
- [ ] Log rotation if appending to logs
