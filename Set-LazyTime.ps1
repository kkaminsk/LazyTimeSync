# Ensure script runs elevated in Intune (Run this script using the logged on credentials = No)
# Configures W32Time service and Geolocation service (lfsvc)

$serviceName = "W32Time"
$logDir = "C:\ProgramData\LazyTime"
$logTimestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"
$logPath = "$logDir\W32Time-Intune-$logTimestamp.log"
$ntpServers = "0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org"
$logRetentionDays = 30

# Geolocation service configuration
$geolocationServiceName = "lfsvc"
$locationPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
$locationConsentPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"

function Remove-OldLogs {
    if (Test-Path -Path $logDir) {
        $cutoffDate = (Get-Date).AddDays(-$logRetentionDays)
        Get-ChildItem -Path $logDir -Filter "W32Time-Intune-*.log" |
            Where-Object { $_.LastWriteTime -lt $cutoffDate } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

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
    Remove-OldLogs
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

    # Check if W32Time service is properly registered
    Write-Log "Checking W32Time service registration"
    $registrationCheck = w32tm /query /status 2>&1
    if ($registrationCheck -match "not registered" -or $registrationCheck -match "service has not been started") {
        Write-Log "W32Time service needs registration, registering now"
        $registerResult = w32tm /register 2>&1
        Write-Log "Registration result: $registerResult"

        # Restart the service after registration
        Write-Log "Restarting $serviceName service after registration"
        Restart-Service -Name $serviceName -Force
        Start-Sleep -Seconds 2
        $newStatus = (Get-Service -Name $serviceName).Status
        Write-Log "$serviceName service status after restart: $newStatus"
    } else {
        Write-Log "W32Time service is already registered"
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

    # ========== Geolocation Service Configuration ==========
    Write-Log "========== Starting Geolocation Service Configuration =========="

    # Configure LocationAndSensors registry policies
    Write-Log "Configuring LocationAndSensors registry policies"
    if (-not (Test-Path -Path $locationPolicyPath)) {
        Write-Log "Creating LocationAndSensors registry key"
        New-Item -Path $locationPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $locationPolicyPath -Name "DisableLocation" -Type DWord -Value 0
    Write-Log "Set DisableLocation = 0"
    Set-ItemProperty -Path $locationPolicyPath -Name "DisableWindowsLocationProvider" -Type DWord -Value 0
    Write-Log "Set DisableWindowsLocationProvider = 0"
    Set-ItemProperty -Path $locationPolicyPath -Name "DisableLocationScripting" -Type DWord -Value 0
    Write-Log "Set DisableLocationScripting = 0"
    Write-Log "LocationAndSensors registry policies configured successfully"

    # Configure CapabilityAccessManager consent for location
    Write-Log "Configuring CapabilityAccessManager location consent"
    if (-not (Test-Path -Path $locationConsentPath)) {
        Write-Log "Creating location consent registry key"
        New-Item -Path $locationConsentPath -Force | Out-Null
    }
    Set-ItemProperty -Path $locationConsentPath -Name "Value" -Type String -Value "Allow"
    Write-Log "Set location consent Value = Allow"

    # Create lfsvc service if missing
    Write-Log "Checking $geolocationServiceName service"
    $geoService = Get-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue
    if (-not $geoService) {
        Write-Log "$geolocationServiceName service not found, creating it"
        $createResult = sc.exe create lfsvc binPath= "%SystemRoot%\System32\svchost.exe -k netsvcs" DisplayName= "@%SystemRoot%\System32\lfsvc.dll,-1" start= demand 2>&1
        Write-Log "Service creation result: $createResult"
    } else {
        Write-Log "$geolocationServiceName service already exists"
    }

    # Set lfsvc startup type to Manual and start service
    Write-Log "Setting $geolocationServiceName service startup type to Manual"
    Set-Service -Name $geolocationServiceName -StartupType Manual -ErrorAction SilentlyContinue
    Write-Log "Starting $geolocationServiceName service"
    Start-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $geoStatus = (Get-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue).Status
    Write-Log "$geolocationServiceName service status: $geoStatus"

    Write-Log "========== Geolocation Service Configuration Completed =========="

    Write-Log "========== All Configuration Completed Successfully =========="
    exit 0

} catch {
    Write-Log "Error occurred: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-Log "========== W32Time Configuration Failed ==========" -Level "ERROR"
    exit 1
}
