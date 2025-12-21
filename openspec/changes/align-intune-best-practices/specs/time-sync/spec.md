## ADDED Requirements

### Requirement: Transcript-Based Logging

Scripts SHALL use PowerShell's `Start-Transcript` and `Stop-Transcript` cmdlets for comprehensive logging instead of manual file appending.

#### Scenario: Detection Script Transcript
- **WHEN** the detection script executes
- **THEN** it SHALL start a transcript to `C:\ProgramData\LazyTime\Detect-LazyTime.log`
- **AND** the transcript SHALL be stopped in a `finally` block

#### Scenario: Remediation Script Transcript
- **WHEN** the remediation script executes
- **THEN** it SHALL start a transcript to `C:\ProgramData\LazyTime\Remediate-LazyTime.log`
- **AND** the transcript SHALL be stopped in a `finally` block

### Requirement: Size-Based Log Rotation

Scripts SHALL implement size-based log rotation to prevent disk exhaustion.

#### Scenario: Log File Exceeds Threshold
- **WHEN** a log file exceeds 5MB before transcript start
- **THEN** the script SHALL rename the file with a `.YYYYMMDD-HHmmss.old` suffix
- **AND** the script SHALL create a new log file

#### Scenario: Archive Pruning
- **WHEN** log rotation creates archive files
- **THEN** the script SHALL retain only the 3 most recent archives
- **AND** older archives SHALL be deleted

### Requirement: Console Output Discipline

Scripts SHALL limit console output to a single concise status message to stay within Intune's 2048-character limit.

#### Scenario: Detection Console Output
- **WHEN** the detection script completes
- **THEN** it SHALL output only "Compliant" or "Non-Compliant" to STDOUT

#### Scenario: Remediation Console Output
- **WHEN** the remediation script completes
- **THEN** it SHALL output only a single summary line to STDOUT
- **AND** detailed operation logs SHALL be written only to the transcript file

### Requirement: Script Documentation Headers

Scripts SHALL include PowerShell comment-based help blocks for discoverability and maintainability.

#### Scenario: Detection Script Header
- **WHEN** viewing the detection script source
- **THEN** it SHALL contain a `.SYNOPSIS` describing its purpose
- **AND** it SHALL contain a `.DESCRIPTION` with compliance check details

#### Scenario: Remediation Script Header
- **WHEN** viewing the remediation script source
- **THEN** it SHALL contain a `.SYNOPSIS` describing its purpose
- **AND** it SHALL contain a `.DESCRIPTION` with configuration actions

## MODIFIED Requirements

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

#### Scenario: Detection Log File Name
- **WHEN** the detection script creates a log file
- **THEN** the filename SHALL be `Detect-LazyTime.log`

#### Scenario: Remediation Log File Name
- **WHEN** the remediation script creates a log file
- **THEN** the filename SHALL be `Remediate-LazyTime.log`
