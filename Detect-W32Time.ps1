# Detection script for Intune - Checks W32Time service status, NTP configuration, and time drift
# Exit 0 = Compliant (detected), Exit 1 = Non-compliant (not detected)

$serviceName = "W32Time"
$logPath = "C:\ProgramData\W32Time\W32Time-Detection.log"
$expectedNtpServers = @("0.ca.pool.ntp.org", "1.ca.pool.ntp.org", "2.ca.pool.ntp.org", "3.ca.pool.ntp.org")
$maxDriftSeconds = 300

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $logDir = Split-Path -Path $logPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logEntry | Out-File -FilePath $logPath -Append -Encoding utf8
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

try {
    Write-Log "========== Starting W32Time Detection =========="
    Write-Log "Computer Name: $env:COMPUTERNAME"
    $detectionPassed = $true

    # Check 1: W32Time service is running
    Write-Log "Check 1: Verifying $serviceName service status"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Log "$serviceName service not found" -Level "ERROR"
        $detectionPassed = $false
    } elseif ($service.Status -ne 'Running') {
        Write-Log "$serviceName service is not running. Current status: $($service.Status)" -Level "ERROR"
        $detectionPassed = $false
    } else {
        Write-Log "$serviceName service is running - PASS"
    }

    # Check 2: NTP servers are configured correctly
    Write-Log "Check 2: Verifying NTP server configuration"
    $w32tmConfig = w32tm /query /peers 2>&1 | Out-String

    $allServersConfigured = $true
    foreach ($server in $expectedNtpServers) {
        if ($w32tmConfig -notmatch [regex]::Escape($server)) {
            Write-Log "NTP server '$server' is not configured" -Level "ERROR"
            $allServersConfigured = $false
        } else {
            Write-Log "NTP server '$server' is configured - PASS"
        }
    }

    if (-not $allServersConfigured) {
        Write-Log "Not all expected NTP servers are configured" -Level "ERROR"
        $detectionPassed = $false
    } else {
        Write-Log "All expected NTP servers are configured - PASS"
    }

    # Check 3: Time drift is within acceptable range
    Write-Log "Check 3: Verifying time drift is within $maxDriftSeconds seconds"
    $ntpTime = $null
    $testedServer = $null

    foreach ($server in $expectedNtpServers) {
        Write-Log "Attempting to query time from $server"
        $ntpTime = Get-NtpTime -NtpServer $server
        if ($null -ne $ntpTime) {
            $testedServer = $server
            Write-Log "Successfully retrieved time from $server"
            break
        } else {
            Write-Log "Failed to retrieve time from $server" -Level "WARNING"
        }
    }

    if ($null -eq $ntpTime) {
        Write-Log "Could not retrieve time from any NTP server" -Level "ERROR"
        $detectionPassed = $false
    } else {
        $localTime = [DateTime]::UtcNow
        $timeDrift = [Math]::Abs(($localTime - $ntpTime).TotalSeconds)

        Write-Log "NTP Server ($testedServer) time (UTC): $($ntpTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "Local system time (UTC): $($localTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "Time drift: $([Math]::Round($timeDrift, 2)) seconds"

        if ($timeDrift -gt $maxDriftSeconds) {
            Write-Log "Time drift ($([Math]::Round($timeDrift, 2)) seconds) exceeds maximum allowed ($maxDriftSeconds seconds)" -Level "ERROR"
            $detectionPassed = $false
        } else {
            Write-Log "Time drift is within acceptable range - PASS"
        }
    }

    # Final result
    if ($detectionPassed) {
        Write-Log "========== Detection Result: SUCCESS =========="
        Write-Output "Compliant"
        exit 0
    } else {
        Write-Log "========== Detection Result: FAILED ==========" -Level "ERROR"
        Write-Output "Non-Compliant"
        exit 1
    }

} catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "========== Detection Result: FAILED ==========" -Level "ERROR"
    Write-Output "Non-Compliant"
    exit 1
}
