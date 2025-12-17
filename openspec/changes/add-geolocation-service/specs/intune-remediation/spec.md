## ADDED Requirements

### Requirement: Geolocation Service Detection

The detection script SHALL verify the Windows Geolocation Service (lfsvc) is properly configured and running.

#### Scenario: Service running check
- **WHEN** the detection script runs
- **THEN** it SHALL check if the lfsvc service exists and is running
- **AND** log the service status

#### Scenario: Service not found
- **WHEN** the lfsvc service does not exist
- **THEN** the detection SHALL fail (non-compliant)
- **AND** log an ERROR indicating the service is missing

#### Scenario: Service not running
- **WHEN** the lfsvc service exists but is not running
- **THEN** the detection SHALL fail (non-compliant)
- **AND** log an ERROR indicating the service is stopped

### Requirement: Location Registry Policy Detection

The detection script SHALL verify the LocationAndSensors registry policies are configured to allow location services.

#### Scenario: Registry policy check
- **WHEN** the detection script runs
- **THEN** it SHALL verify the following registry values at `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`:
  - `DisableLocation` = 0
  - `DisableWindowsLocationProvider` = 0
  - `DisableLocationScripting` = 0

#### Scenario: Policy keys missing
- **WHEN** the LocationAndSensors registry key does not exist
- **THEN** the detection SHALL fail (non-compliant)
- **AND** log an ERROR indicating the policy key is missing

#### Scenario: Policy values incorrect
- **WHEN** any policy value is not 0 (location disabled)
- **THEN** the detection SHALL fail (non-compliant)
- **AND** log an ERROR indicating which policy is misconfigured

### Requirement: Location Consent Detection

The detection script SHALL verify the CapabilityAccessManager consent for location is set to Allow.

#### Scenario: Consent check
- **WHEN** the detection script runs
- **THEN** it SHALL verify the registry value at `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location` has `Value` = "Allow"

#### Scenario: Consent not allowed
- **WHEN** the consent value is not "Allow"
- **THEN** the detection SHALL fail (non-compliant)
- **AND** log an ERROR indicating location consent is not enabled

### Requirement: Geolocation Service Remediation

The remediation script SHALL configure the Windows Geolocation Service (lfsvc) for proper operation.

#### Scenario: Create missing service
- **WHEN** the lfsvc service does not exist
- **THEN** the remediation script SHALL create it using `sc.exe create lfsvc`
- **AND** log the creation result

#### Scenario: Configure service startup
- **WHEN** remediation runs
- **THEN** the script SHALL set lfsvc startup type to Manual
- **AND** start the service if not running
- **AND** log the service status after configuration

### Requirement: Location Registry Policy Remediation

The remediation script SHALL configure the LocationAndSensors registry policies to enable location services.

#### Scenario: Create and set registry policies
- **WHEN** remediation runs
- **THEN** the script SHALL create (if needed) and set the following at `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`:
  - `DisableLocation` = 0 (DWORD)
  - `DisableWindowsLocationProvider` = 0 (DWORD)
  - `DisableLocationScripting` = 0 (DWORD)
- **AND** log each registry operation

### Requirement: Location Consent Remediation

The remediation script SHALL configure the CapabilityAccessManager consent for location.

#### Scenario: Set consent to Allow
- **WHEN** remediation runs
- **THEN** the script SHALL create (if needed) and set the registry value at `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location` with `Value` = "Allow" (String)
- **AND** log the consent configuration result
