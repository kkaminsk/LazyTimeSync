## ADDED Requirements

### Requirement: LazyTimeSync Naming Convention

Scripts and log directories SHALL use the "LazyTime" naming prefix for brand consistency.

#### Scenario: Detection Script Naming
- **WHEN** the detection script is deployed
- **THEN** it SHALL be named `Detect-LazyTime.ps1`

#### Scenario: Remediation Script Naming
- **WHEN** the remediation script is deployed
- **THEN** it SHALL be named `Set-LazyTime.ps1`

#### Scenario: Log Directory Location
- **WHEN** either script writes log files
- **THEN** logs SHALL be stored in `C:\ProgramData\LazyTime`

#### Scenario: Log File Pattern
- **WHEN** a log file is created
- **THEN** the filename SHALL follow the pattern `W32Time-Intune-YYYY-MM-DD-HH-mm.log`
