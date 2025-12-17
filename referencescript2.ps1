# Run in elevated PowerShell

# 1) Make sure policy is not disabling Location
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" `
    -Name "DisableLocation" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" `
    -Name "DisableWindowsLocationProvider" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" `
    -Name "DisableLocationScripting" -Type DWord -Value 0

# 2) Ensure capability consent is Allow for system
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" `
    -Name "Value" -Type String -Value "Allow"

# 3) Recreate lfsvc (Geolocation Service) if missing
$svc = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
if (-not $svc) {
    sc.exe create lfsvc binPath= "%SystemRoot%\System32\svchost.exe -k netsvcs" `
        DisplayName= "@%SystemRoot%\System32\lfsvc.dll,-1" start= demand
}

# 4) Set startup to Manual and start the service
Set-Service -Name "lfsvc" -StartupType Manual
Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
