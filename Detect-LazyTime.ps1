<#
.SYNOPSIS
    Intune Detection Script - Checks W32Time service, NTP configuration, time drift, and Geolocation service.

.DESCRIPTION
    This detection script performs six compliance checks for Intune Remediations:
    1. W32Time service must be running
    2. All expected NTP servers must be configured
    3. Local time must be within 300 seconds of NTP time
    4. Geolocation service (lfsvc) must be running
    5. LocationAndSensors registry policies must allow location
    6. CapabilityAccessManager consent must be "Allow"

    Exit codes:
    - Exit 0 = Compliant (all checks pass)
    - Exit 1 = Non-Compliant (any check fails)
#>

# --- Configuration ---
$serviceName = "W32Time"
$logDir = "C:\ProgramData\LazyTime"
$logPath = "$logDir\Detect-LazyTime.log"
$expectedNtpServers = @("0.ca.pool.ntp.org", "1.ca.pool.ntp.org", "2.ca.pool.ntp.org", "3.ca.pool.ntp.org")
$maxDriftSeconds = 300
$logRetentionDays = 30
$maxLogSizeMB = 5
$maxLogArchives = 3

# Geolocation service configuration
$geolocationServiceName = "lfsvc"
$locationPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
$locationConsentPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
$expectedLocationPolicies = @{
    "DisableLocation" = 0
    "DisableWindowsLocationProvider" = 0
    "DisableLocationScripting" = 0
}

# --- Helper Functions ---

function Invoke-LogRotation {
    param(
        [string]$Path,
        [int]$MaxSizeMB = 5,
        [int]$MaxArchives = 3
    )

    if (Test-Path $Path) {
        $logFile = Get-Item $Path
        if ($logFile.Length -gt ($MaxSizeMB * 1MB)) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $archiveName = "$Path.$timestamp.old"
            Rename-Item -Path $Path -NewName $archiveName -Force

            # Prune old archives
            $parentDir = Split-Path $Path -Parent
            $baseName = Split-Path $Path -Leaf
            $oldArchives = Get-ChildItem -Path $parentDir -Filter "$baseName.*.old" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending

            if ($oldArchives.Count -gt $MaxArchives) {
                $oldArchives | Select-Object -Skip $MaxArchives | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-OldLogs {
    if (Test-Path -Path $logDir) {
        $cutoffDate = (Get-Date).AddDays(-$logRetentionDays)

        # Clean up legacy timestamped log files
        Get-ChildItem -Path $logDir -Filter "W32Time-Intune-*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate } |
            Remove-Item -Force -ErrorAction SilentlyContinue

        # Clean up old archive files beyond retention
        Get-ChildItem -Path $logDir -Filter "*.old" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Get-NtpTime {
    param([string]$NtpServer)

    try {
        $ntpData = New-Object byte[] 48
        $ntpData[0] = 0x1B  # NTP request header

        $socket = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
        $socket.SendTimeout = 5000
        $socket.ReceiveTimeout = 5000

        $socket.Connect($NtpServer, 123)
        [void]$socket.Send($ntpData)
        [void]$socket.Receive($ntpData)
        $socket.Close()

        # Extract timestamp from response (bytes 40-47)
        $intPart = [BitConverter]::ToUInt32($ntpData[43..40], 0)
        $fracPart = [BitConverter]::ToUInt32($ntpData[47..44], 0)

        # Convert NTP timestamp to DateTime (NTP epoch is 1900-01-01)
        $ntpTime = (New-Object DateTime(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).AddSeconds($intPart).AddSeconds($fracPart / [Math]::Pow(2, 32))

        return $ntpTime
    } catch {
        return $null
    }
}

# --- Main Execution ---

# Ensure log directory exists
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Perform log maintenance
Remove-OldLogs
Invoke-LogRotation -Path $logPath -MaxSizeMB $maxLogSizeMB -MaxArchives $maxLogArchives

# Start transcript logging
try {
    Start-Transcript -Path $logPath -Append -Force -ErrorAction SilentlyContinue

    Write-Output "========== Starting W32Time Detection =========="
    Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "Computer Name: $env:COMPUTERNAME"

    $detectionPassed = $true

    # Check 1: W32Time service is running
    Write-Output "Check 1: Verifying $serviceName service status"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Output "[ERROR] $serviceName service not found"
        $detectionPassed = $false
    } elseif ($service.Status -ne 'Running') {
        Write-Output "[ERROR] $serviceName service is not running. Current status: $($service.Status)"
        $detectionPassed = $false
    } else {
        Write-Output "[PASS] $serviceName service is running"
    }

    # Check 2: NTP servers are configured correctly
    Write-Output "Check 2: Verifying NTP server configuration"
    $w32tmConfig = w32tm /query /peers 2>&1 | Out-String

    $allServersConfigured = $true
    foreach ($server in $expectedNtpServers) {
        if ($w32tmConfig -notmatch [regex]::Escape($server)) {
            Write-Output "[ERROR] NTP server '$server' is not configured"
            $allServersConfigured = $false
        } else {
            Write-Output "[PASS] NTP server '$server' is configured"
        }
    }

    if (-not $allServersConfigured) {
        Write-Output "[ERROR] Not all expected NTP servers are configured"
        $detectionPassed = $false
    } else {
        Write-Output "[PASS] All expected NTP servers are configured"
    }

    # Check 3: Time drift is within acceptable range
    Write-Output "Check 3: Verifying time drift is within $maxDriftSeconds seconds"
    $ntpTime = $null
    $testedServer = $null

    foreach ($server in $expectedNtpServers) {
        Write-Output "Attempting to query time from $server"
        $ntpTime = Get-NtpTime -NtpServer $server
        if ($null -ne $ntpTime) {
            $testedServer = $server
            Write-Output "Successfully retrieved time from $server"
            break
        } else {
            Write-Output "[WARNING] Failed to retrieve time from $server"
        }
    }

    if ($null -eq $ntpTime) {
        Write-Output "[ERROR] Could not retrieve time from any NTP server"
        $detectionPassed = $false
    } else {
        $localTime = [DateTime]::UtcNow
        $timeDrift = [Math]::Abs(($localTime - $ntpTime).TotalSeconds)

        Write-Output "NTP Server ($testedServer) time (UTC): $($ntpTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Output "Local system time (UTC): $($localTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Output "Time drift: $([Math]::Round($timeDrift, 2)) seconds"

        if ($timeDrift -gt $maxDriftSeconds) {
            Write-Output "[ERROR] Time drift ($([Math]::Round($timeDrift, 2)) seconds) exceeds maximum allowed ($maxDriftSeconds seconds)"
            $detectionPassed = $false
        } else {
            Write-Output "[PASS] Time drift is within acceptable range"
        }
    }

    # Check 4: Geolocation service (lfsvc) is running
    Write-Output "Check 4: Verifying $geolocationServiceName service status"
    $geoService = Get-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue

    if ($null -eq $geoService) {
        Write-Output "[ERROR] $geolocationServiceName service not found"
        $detectionPassed = $false
    } elseif ($geoService.Status -ne 'Running') {
        Write-Output "[ERROR] $geolocationServiceName service is not running. Current status: $($geoService.Status)"
        $detectionPassed = $false
    } else {
        Write-Output "[PASS] $geolocationServiceName service is running"
    }

    # Check 5: LocationAndSensors registry policies
    Write-Output "Check 5: Verifying LocationAndSensors registry policy values"
    if (-not (Test-Path -Path $locationPolicyPath)) {
        Write-Output "[ERROR] LocationAndSensors registry key not found at $locationPolicyPath"
        $detectionPassed = $false
    } else {
        $allPoliciesCorrect = $true
        foreach ($policy in $expectedLocationPolicies.GetEnumerator()) {
            $currentValue = Get-ItemProperty -Path $locationPolicyPath -Name $policy.Key -ErrorAction SilentlyContinue
            if ($null -eq $currentValue) {
                Write-Output "[ERROR] Registry value '$($policy.Key)' not found"
                $allPoliciesCorrect = $false
            } elseif ($currentValue.($policy.Key) -ne $policy.Value) {
                Write-Output "[ERROR] Registry value '$($policy.Key)' is $($currentValue.($policy.Key)), expected $($policy.Value)"
                $allPoliciesCorrect = $false
            } else {
                Write-Output "[PASS] Registry value '$($policy.Key)' = $($policy.Value)"
            }
        }
        if (-not $allPoliciesCorrect) {
            Write-Output "[ERROR] Not all LocationAndSensors policies are correctly configured"
            $detectionPassed = $false
        } else {
            Write-Output "[PASS] All LocationAndSensors policies are correctly configured"
        }
    }

    # Check 6: CapabilityAccessManager consent for location
    Write-Output "Check 6: Verifying CapabilityAccessManager location consent"
    if (-not (Test-Path -Path $locationConsentPath)) {
        Write-Output "[ERROR] Location consent registry key not found at $locationConsentPath"
        $detectionPassed = $false
    } else {
        $consentValue = Get-ItemProperty -Path $locationConsentPath -Name "Value" -ErrorAction SilentlyContinue
        if ($null -eq $consentValue) {
            Write-Output "[ERROR] Location consent 'Value' property not found"
            $detectionPassed = $false
        } elseif ($consentValue.Value -ne "Allow") {
            Write-Output "[ERROR] Location consent is '$($consentValue.Value)', expected 'Allow'"
            $detectionPassed = $false
        } else {
            Write-Output "[PASS] Location consent is 'Allow'"
        }
    }

    # Final result (logged to transcript)
    if ($detectionPassed) {
        Write-Output "========== Detection Result: COMPLIANT =========="
    } else {
        Write-Output "========== Detection Result: NON-COMPLIANT =========="
    }

} catch {
    Write-Output "[ERROR] Unexpected error: $($_.Exception.Message)"
    Write-Output "========== Detection Result: FAILED =========="
    $detectionPassed = $false
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue
}

# Console output for Intune (single line only)
if ($detectionPassed) {
    Write-Output "Compliant"
    exit 0
} else {
    Write-Output "Non-Compliant"
    exit 1
}
