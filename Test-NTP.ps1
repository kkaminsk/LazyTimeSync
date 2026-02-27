<#
.SYNOPSIS
    Tests outbound NTP connectivity to configured NTP servers.

.DESCRIPTION
    This script tests UDP port 123 connectivity to NTP pool servers
    using raw UDP sockets (no dependency on the local W32Time service).
    Run this before deploying W32Time remediation scripts to verify
    firewall rules allow outbound NTP traffic.

.NOTES
    Run as Administrator for best results.
    Requires: Windows 10/11 or Windows Server 2016+
#>

#Requires -Version 5.1

$scriptVersion = "1.2.0"

# Adjust NTP servers for your geographic region or internal NTP infrastructure.
# Must stay synchronized with $expectedNtpServers in Detect-LazyTime.ps1 and $ntpServers in Set-LazyTime.ps1.
$ntpServers = @(
    "0.ca.pool.ntp.org",
    "1.ca.pool.ntp.org",
    "2.ca.pool.ntp.org",
    "3.ca.pool.ntp.org"
)

# --- Helper Functions ---
# Note: Get-NtpTime is intentionally duplicated from Detect-LazyTime.ps1.
# Each script must be self-contained. Keep changes synchronized.

function Get-NtpTime {
    param([string]$NtpServer)

    $socket = $null
    try {
        $ntpData = New-Object byte[] 48
        # NTP request header: 0x1B = 00 011 011 binary (LI=0 no warning, VN=3 NTPv3, Mode=3 client)
        $ntpData[0] = 0x1B

        $socket = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
        $socket.SendTimeout = 5000
        $socket.ReceiveTimeout = 5000

        $socket.Connect($NtpServer, 123)
        [void]$socket.Send($ntpData)
        [void]$socket.Receive($ntpData)

        # Extract timestamp from response (bytes 40-47)
        # Reverse indexing converts big-endian NTP bytes to little-endian for x86/x64
        $intPart = [BitConverter]::ToUInt32($ntpData[43..40], 0)
        $fracPart = [BitConverter]::ToUInt32($ntpData[47..44], 0)

        # Convert NTP timestamp to DateTime (NTP epoch is 1900-01-01)
        $ntpTime = (New-Object DateTime(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).AddSeconds($intPart).AddSeconds($fracPart / [Math]::Pow(2, 32))

        return $ntpTime
    } catch {
        return $null
    } finally {
        if ($socket) { $socket.Dispose() }
    }
}

$results = @()

Write-Host "`n========== NTP Connectivity Test ==========" -ForegroundColor Cyan
Write-Host "Testing outbound UDP port 123 to NTP servers (raw socket, no W32Time dependency)`n"

foreach ($server in $ntpServers) {
    Write-Host "Testing: $server" -ForegroundColor Yellow

    # Resolve DNS first
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($server) | Select-Object -First 1
        Write-Host "  DNS resolved to: $($resolved.IPAddressToString)" -ForegroundColor Gray
    }
    catch {
        Write-Host "  DNS resolution FAILED" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Server = $server
            Status = "FAIL"
            Details = "DNS resolution failed"
        }
        continue
    }

    # Test NTP query using raw UDP socket (independent of W32Time service)
    $ntpTime = Get-NtpTime -NtpServer $server
    if ($null -ne $ntpTime) {
        $localTime = [DateTime]::UtcNow
        $offset = [Math]::Round(($localTime - $ntpTime).TotalSeconds, 3)
        Write-Host "  NTP query SUCCESS (offset: ${offset}s)" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Server = $server
            Status = "PASS"
            Details = "Offset: ${offset}s"
        }
    } else {
        Write-Host "  NTP query FAILED" -ForegroundColor Red
        Write-Host "  Error: No response - check firewall UDP 123" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Server = $server
            Status = "FAIL"
            Details = "No response - check firewall UDP 123"
        }
    }

    Write-Host ""
}

# Summary
Write-Host "========== Test Results Summary ==========" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Host "Passed: $passed / $($results.Count)" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })

if ($failed -gt 0) {
    Write-Host "Failed: $failed / $($results.Count)" -ForegroundColor Red
    Write-Host "`nRecommendation: Ensure UDP port 123 is open outbound to NTP servers." -ForegroundColor Yellow
    Write-Host "Firewall rule needed: UDP 123 Outbound to *.pool.ntp.org`n" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "`nAll NTP servers are reachable. Safe to deploy W32Time scripts.`n" -ForegroundColor Green
    exit 0
}
