<#
.SYNOPSIS
    Intune Remediation Script - Configures W32Time service, NTP servers, and Geolocation service.

.DESCRIPTION
    This remediation script configures the following when detection finds non-compliance:
    1. Sets W32Time service to Automatic startup and starts it
    2. Registers the W32Time service if needed
    3. Configures NTP servers via w32tm
    4. Forces immediate time synchronization
    5. Creates LocationAndSensors registry policies
    6. Sets CapabilityAccessManager consent to "Allow"
    7. Configures and starts the Geolocation service (lfsvc)

    Exit codes:
    - Exit 0 = Remediation successful
    - Exit 1 = Remediation failed
#>

# --- Configuration ---
$serviceName = "W32Time"
$logDir = "C:\ProgramData\LazyTime"
$logPath = "$logDir\Remediate-LazyTime.log"
$ntpServers = "0.ca.pool.ntp.org,1.ca.pool.ntp.org,2.ca.pool.ntp.org,3.ca.pool.ntp.org"
$logRetentionDays = 30
$maxLogSizeMB = 5
$maxLogArchives = 3

# Geolocation service configuration
$geolocationServiceName = "lfsvc"
$locationPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
$locationConsentPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"

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

# --- Main Execution ---

# Ensure log directory exists
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Perform log maintenance
Remove-OldLogs
Invoke-LogRotation -Path $logPath -MaxSizeMB $maxLogSizeMB -MaxArchives $maxLogArchives

# Track remediation success
$remediationSuccess = $true

try {
    Start-Transcript -Path $logPath -Append -Force -ErrorAction SilentlyContinue

    Write-Output "========== Starting W32Time Remediation =========="
    Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "Computer Name: $env:COMPUTERNAME"
    Write-Output "Script executed by: $env:USERNAME"

    # Set Windows Time service startup type to Automatic
    Write-Output "Setting $serviceName service startup type to Automatic"
    Set-Service -Name $serviceName -StartupType Automatic
    Write-Output "Service startup type set successfully"

    # Start the Windows Time service if not running
    $serviceStatus = (Get-Service -Name $serviceName).Status
    Write-Output "Current $serviceName service status: $serviceStatus"

    if ($serviceStatus -ne 'Running') {
        Write-Output "Starting $serviceName service"
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 2
        $newStatus = (Get-Service -Name $serviceName).Status
        Write-Output "$serviceName service status after start attempt: $newStatus"
    } else {
        Write-Output "$serviceName service is already running"
    }

    # Check if W32Time service is properly registered
    Write-Output "Checking W32Time service registration"
    $registrationCheck = w32tm /query /status 2>&1
    if ($registrationCheck -match "not registered" -or $registrationCheck -match "service has not been started") {
        Write-Output "W32Time service needs registration, registering now"
        $registerResult = w32tm /register 2>&1
        Write-Output "Registration result: $registerResult"

        # Restart the service after registration
        Write-Output "Restarting $serviceName service after registration"
        Restart-Service -Name $serviceName -Force
        Start-Sleep -Seconds 2
        $newStatus = (Get-Service -Name $serviceName).Status
        Write-Output "$serviceName service status after restart: $newStatus"
    } else {
        Write-Output "W32Time service is already registered"
    }

    # Configure NTP servers
    Write-Output "Configuring NTP servers: $ntpServers"
    $configResult = w32tm /config /manualpeerlist:"$ntpServers" /syncfromflags:manual /reliable:yes /update 2>&1
    Write-Output "NTP configuration result: $configResult"

    # Force an immediate time sync
    Write-Output "Forcing immediate time synchronization"
    $resyncResult = w32tm /resync /force 2>&1
    Write-Output "Resync result: $resyncResult"

    # Query current configuration for verification
    Write-Output "Querying current W32Time configuration"
    $queryResult = w32tm /query /status 2>&1
    Write-Output "Current W32Time status: $queryResult"

    $peersResult = w32tm /query /peers 2>&1
    Write-Output "Configured peers: $peersResult"

    # ========== Geolocation Service Configuration ==========
    Write-Output "========== Starting Geolocation Service Configuration =========="

    # Configure LocationAndSensors registry policies
    Write-Output "Configuring LocationAndSensors registry policies"
    if (-not (Test-Path -Path $locationPolicyPath)) {
        Write-Output "Creating LocationAndSensors registry key"
        New-Item -Path $locationPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $locationPolicyPath -Name "DisableLocation" -Type DWord -Value 0
    Write-Output "Set DisableLocation = 0"
    Set-ItemProperty -Path $locationPolicyPath -Name "DisableWindowsLocationProvider" -Type DWord -Value 0
    Write-Output "Set DisableWindowsLocationProvider = 0"
    Set-ItemProperty -Path $locationPolicyPath -Name "DisableLocationScripting" -Type DWord -Value 0
    Write-Output "Set DisableLocationScripting = 0"
    Write-Output "LocationAndSensors registry policies configured successfully"

    # Configure CapabilityAccessManager consent for location
    Write-Output "Configuring CapabilityAccessManager location consent"
    if (-not (Test-Path -Path $locationConsentPath)) {
        Write-Output "Creating location consent registry key"
        New-Item -Path $locationConsentPath -Force | Out-Null
    }
    Set-ItemProperty -Path $locationConsentPath -Name "Value" -Type String -Value "Allow"
    Write-Output "Set location consent Value = Allow"

    # Create lfsvc service if missing
    Write-Output "Checking $geolocationServiceName service"
    $geoService = Get-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue
    if (-not $geoService) {
        Write-Output "$geolocationServiceName service not found, creating it"
        $createResult = sc.exe create lfsvc binPath= "%SystemRoot%\System32\svchost.exe -k netsvcs" DisplayName= "@%SystemRoot%\System32\lfsvc.dll,-1" start= demand 2>&1
        Write-Output "Service creation result: $createResult"
    } else {
        Write-Output "$geolocationServiceName service already exists"
    }

    # Set lfsvc startup type to Manual and start service
    Write-Output "Setting $geolocationServiceName service startup type to Manual"
    Set-Service -Name $geolocationServiceName -StartupType Manual -ErrorAction SilentlyContinue
    Write-Output "Starting $geolocationServiceName service"
    Start-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $geoStatus = (Get-Service -Name $geolocationServiceName -ErrorAction SilentlyContinue).Status
    Write-Output "$geolocationServiceName service status: $geoStatus"

    Write-Output "========== Geolocation Service Configuration Completed =========="
    Write-Output "========== All Configuration Completed Successfully =========="

} catch {
    Write-Output "[ERROR] Error occurred: $($_.Exception.Message)"
    Write-Output "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    Write-Output "========== W32Time Remediation Failed =========="
    $remediationSuccess = $false
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue
}

# Console output for Intune (single line only)
if ($remediationSuccess) {
    Write-Output "Remediation completed successfully"
    exit 0
} else {
    Write-Output "Remediation failed"
    exit 1
}
