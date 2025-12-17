## Why

Devices need both accurate time synchronization (W32Time) and location services (lfsvc) enabled for full functionality. The geolocation service is required for timezone detection, location-aware applications, and Windows features that depend on location data. Combining both concerns in a single Intune remediation package simplifies deployment and ensures consistent system configuration.

## What Changes

- **Detect-LazyW32Time.ps1**: Add checks for:
  - Geolocation Service (lfsvc) running status
  - Registry policy settings for LocationAndSensors (DisableLocation, DisableWindowsLocationProvider, DisableLocationScripting)
  - CapabilityAccessManager consent store value for location

- **Set-LazyW32TimeandLocationServices.ps1**: Add remediation for:
  - Create and configure LocationAndSensors registry keys
  - Set CapabilityAccessManager consent to "Allow"
  - Create lfsvc service if missing
  - Set lfsvc startup type to Manual and start the service

## Impact

- **Affected scripts**:
  - `Detect-LazyW32Time.ps1` - Add 3 new detection checks (service, registry policies, consent)
  - `Set-LazyW32TimeandLocationServices.ps1` - Add geolocation remediation logic

- **Affected documentation**:
  - `README.md` - Update to document new geolocation checks
  - `CLAUDE.md` - Update project structure and variables

- **No breaking changes**: Existing W32Time functionality remains unchanged; geolocation checks are additive
