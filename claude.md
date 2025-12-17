# LazyTimeSyncStuff

Intune remediation scripts for Windows Time (W32Time) service configuration and monitoring.

## Scripts

- **Test-NTP.ps1** - Pre-deployment test script to verify outbound UDP 123 connectivity to NTP servers
- **Set-W32Time.ps1** - Remediation script that configures W32Time service, registers the service if needed, sets NTP servers, and forces time sync
- **Detect-W32Time.ps1** - Detection script that verifies service status, NTP configuration, and time drift compliance

## Intune Deployment

- Detection script: Exit 0 = Compliant, Exit 1 = Non-compliant
- Remediation script: Runs when detection fails
- Both scripts require elevation (Run as: System)

## Configuration

- NTP Servers: Canadian NTP pool (0-3.ca.pool.ntp.org)
- Max allowed time drift: 300 seconds
- Log location: `C:\ProgramData\W32Time\`
- Log retention: 30 days
