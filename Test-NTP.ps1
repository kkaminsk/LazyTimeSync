<#
.SYNOPSIS
    Tests outbound NTP connectivity to configured NTP servers.

.DESCRIPTION
    This script tests UDP port 123 connectivity to NTP pool servers.
    Run this before deploying W32Time remediation scripts to verify
    firewall rules allow outbound NTP traffic.

.NOTES
    Run as Administrator for best results.
    Requires: Windows 10/11 or Windows Server 2016+
#>

#Requires -Version 5.1

# NTP servers to test (same as remediation scripts)
$ntpServers = @(
    "0.ca.pool.ntp.org",
    "1.ca.pool.ntp.org",
    "2.ca.pool.ntp.org",
    "3.ca.pool.ntp.org"
)

$samplesPerServer = 3
$results = @()

Write-Host "`n========== NTP Connectivity Test ==========" -ForegroundColor Cyan
Write-Host "Testing outbound UDP port 123 to NTP servers`n"

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

    # Test NTP query using w32tm
    try {
        $output = w32tm /stripchart /computer:$server /samples:$samplesPerServer /dataonly 2>&1
        $outputStr = $output -join "`n"

        if ($outputStr -match "error|0x800705B4|timed out") {
            Write-Host "  NTP query FAILED" -ForegroundColor Red
            Write-Host "  Error: Connection timed out or blocked" -ForegroundColor Red
            $results += [PSCustomObject]@{
                Server = $server
                Status = "FAIL"
                Details = "Connection timed out - check firewall UDP 123"
            }
        }
        else {
            # Extract offset from successful response
            $offsetMatch = $output | Select-String -Pattern "([+-]?\d+\.\d+)s$" | Select-Object -Last 1
            if ($offsetMatch) {
                $offset = $offsetMatch.Matches[0].Groups[1].Value
                Write-Host "  NTP query SUCCESS (offset: ${offset}s)" -ForegroundColor Green
                $results += [PSCustomObject]@{
                    Server = $server
                    Status = "PASS"
                    Details = "Offset: ${offset}s"
                }
            }
            else {
                Write-Host "  NTP query SUCCESS" -ForegroundColor Green
                $results += [PSCustomObject]@{
                    Server = $server
                    Status = "PASS"
                    Details = "Response received"
                }
            }
        }
    }
    catch {
        Write-Host "  NTP query FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Server = $server
            Status = "FAIL"
            Details = $_.Exception.Message
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
