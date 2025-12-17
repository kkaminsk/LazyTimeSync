# Ensure script runs elevated in Intune (Run this script using the logged on credentials = No)

$serviceName = "W32Time"
$logPath = "C:\ProgramData\W32Time\W32Time-Intune.log"
$ntpServers = "0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $logDir = Split-Path -Path $logPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logEntry | Out-File -FilePath $logPath -Append -Encoding utf8

    switch ($Level) {
        "ERROR"   { Write-Error $Message }
        "WARNING" { Write-Warning $Message }
        default   { Write-Output $Message }
    }
}

try {
    Write-Log "========== Starting W32Time Configuration =========="
    Write-Log "Computer Name: $env:COMPUTERNAME"
    Write-Log "Script executed by: $env:USERNAME"

    # Set Windows Time service startup type to Automatic
    Write-Log "Setting $serviceName service startup type to Automatic"
    Set-Service -Name $serviceName -StartupType Automatic
    Write-Log "Service startup type set successfully"

    # Start the Windows Time service if not running
    $serviceStatus = (Get-Service -Name $serviceName).Status
    Write-Log "Current $serviceName service status: $serviceStatus"

    if ($serviceStatus -ne 'Running') {
        Write-Log "Starting $serviceName service"
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 2
        $newStatus = (Get-Service -Name $serviceName).Status
        Write-Log "$serviceName service status after start attempt: $newStatus"
    } else {
        Write-Log "$serviceName service is already running"
    }

    # Configure NTP servers
    Write-Log "Configuring NTP servers: $ntpServers"
    $configResult = w32tm /config /manualpeerlist:"$ntpServers" /syncfromflags:manual /reliable:yes /update 2>&1
    Write-Log "NTP configuration result: $configResult"

    # Force an immediate time sync
    Write-Log "Forcing immediate time synchronization"
    $resyncResult = w32tm /resync /force 2>&1
    Write-Log "Resync result: $resyncResult"

    # Query current configuration for verification
    Write-Log "Querying current W32Time configuration"
    $queryResult = w32tm /query /status 2>&1
    Write-Log "Current W32Time status: $queryResult"

    $peersResult = w32tm /query /peers 2>&1
    Write-Log "Configured peers: $peersResult"

    Write-Log "========== W32Time Configuration Completed Successfully =========="
    exit 0

} catch {
    Write-Log "Error occurred: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-Log "========== W32Time Configuration Failed ==========" -Level "ERROR"
    exit 1
}
