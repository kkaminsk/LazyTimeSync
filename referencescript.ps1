# Ensure script runs elevated in Intune (Run this script using the logged on credentials = No)

$serviceName = "W32Time"

try {
    # Set Windows Time service startup type to Automatic
    Set-Service -Name $serviceName -StartupType Automatic

    # Start the Windows Time service
    if ((Get-Service -Name $serviceName).Status -ne 'Running') {
        Start-Service -Name $serviceName
    }

    # Optional: re-register and resync with NTP
    w32tm /unregister
    w32tm /register

    # Configure NTP server (replace with your own, e.g. domain NTP or pool.ntp.org)
    w32tm /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /update

    # Force an immediate time sync
    w32tm /resync /force

} catch {
    # Simple logging to a local file (optional)
    $logPath = "C:\ProgramData\W32Time\W32Time-Intune.log"
    "[$(Get-Date)] Error: $($_.Exception.Message)" | Out-File -FilePath $logPath -Append -Encoding utf8
}
