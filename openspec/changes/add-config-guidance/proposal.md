# Add Configuration Guidance Comments

## Problem

The Gemini code review noted that NTP server variables (`$ntpServers`, `$expectedNtpServers`) are hardcoded, which is standard for Intune (no native parameter passing). However, there are no comments indicating that administrators should adjust these values for their geographic region or internal NTP infrastructure.

## Solution

Add inline comments above the NTP server configuration variables in all three scripts indicating:
- These values are region-specific (currently Canadian NTP pool)
- Administrators should adjust for their geographic region or internal NTP servers
- Values must stay synchronized between detection and remediation scripts

## Impact

- **Detect-LazyTime.ps1** - Comment added above `$expectedNtpServers`
- **Set-LazyTime.ps1** - Comment added above `$ntpServers`
- **Test-NTP.ps1** - Comment added above `$ntpServers`
- Risk: None - comments only, no logic changes
