## 1. Detection Script Updates

- [ ] 1.1 Add configuration variables for geolocation settings (`$geolocationServiceName`, registry paths, expected values)
- [ ] 1.2 Add Check 4: Verify lfsvc service exists and is running
- [ ] 1.3 Add Check 5: Verify LocationAndSensors registry policy values (DisableLocation=0, DisableWindowsLocationProvider=0, DisableLocationScripting=0)
- [ ] 1.4 Add Check 6: Verify CapabilityAccessManager consent store location value is "Allow"

## 2. Remediation Script Updates

- [ ] 2.1 Add configuration variables for geolocation settings (registry paths, service name)
- [ ] 2.2 Add LocationAndSensors registry policy creation and configuration
- [ ] 2.3 Add CapabilityAccessManager consent store configuration
- [ ] 2.4 Add lfsvc service creation if missing (using sc.exe)
- [ ] 2.5 Add lfsvc service startup configuration (Manual) and start service

## 3. Documentation Updates

- [ ] 3.1 Update README.md with new geolocation checks and registry settings
- [ ] 3.2 Update CLAUDE.md project structure section
