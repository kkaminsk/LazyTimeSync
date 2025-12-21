# **Architecting Resilient Endpoint Management: A Comprehensive Guide to Microsoft Intune Remediation Scripts**

## **Executive Summary**

In the contemporary landscape of enterprise mobility and security, the paradigm of endpoint management has shifted fundamentally from monolithic, "golden image" deployment strategies to agile, state-based configuration management. Within the Microsoft ecosystem, Intune Remediations—formerly known as Proactive Remediations—represents the pinnacle of this evolution. This feature enables systems architects and administrators to deploy self-healing logic to the edge, allowing Windows devices to autonomously detect configuration drift, security vulnerabilities, or performance bottlenecks and resolve them without human intervention.

This report serves as an exhaustive technical reference and strategic guide for engineering robust, enterprise-grade remediation workflows. It moves beyond basic script implementation to explore the underlying mechanics of the Intune Management Extension (IME), the rigorous requirements for deterministic detection logic, the architecture of resilient logging frameworks, and the security implications of code execution in high-privilege contexts. By analysing the interaction between detection and remediation scripts, the nuances of the Windows operating system's execution policies, and the limitations of cloud-based reporting, this document provides a blueprint for maintaining a pristine digital estate.

The analysis draws upon technical documentation, community research, and architectural best practices to synthesize a cohesive methodology for deploying PowerShell automations that are not only functional but observant, secure, and maintainable at scale.

## ---

**1\. The Architectural Framework of Intune Remediations**

To engineer effective remediation scripts, one must first possess a granular understanding of the operational environment in which they execute. Intune Remediations are not merely scheduled tasks; they are integral components of a sophisticated policy delivery system orchestrated by the Intune Management Extension agent.

### **1.1 The Intune Management Extension (IME)**

The engine driving remediation scripts is the Intune Management Extension (Microsoft.Management.Services.IntuneWindowsAgent.exe), a service that runs on managed Windows devices. Unlike the native MDM channel, which relies on the Windows OMA-DM (Open Mobile Alliance Device Management) protocol, the IME provides a sidecar capability that allows for the execution of complex PowerShell scripts and Win32 application installers.

The IME operates as a background service running under the LocalSystem account. This high-privilege context is necessary for performing administrative tasks such as installing software, modifying HKLM registry hives, or managing system services. However, it also imposes a significant responsibility on the script author to ensure that operations do not destabilize the system or expose security vulnerabilities.

Agent Orchestration and Polling:  
The IME does not maintain a persistent, real-time connection to the Intune cloud service for script execution. Instead, it adheres to a polling interval.

* **Service Start:** Upon the restart of the IntuneManagementExtension service (or a device reboot), the agent immediately checks for new policies.  
* **User Sign-in:** A check-in is triggered when a user signs into the device, ensuring that user-context scripts are applied relevant to the active session.1  
* **Periodic Polling:** The agent checks for new or updated scripts approximately every 60 minutes, though the specific evaluation of remediation schedules occurs locally based on the policy defined in the script package (e.g., hourly, daily, or one-time execution).1

Understanding this cycle is critical for testing. Administrators often mistakenly assume that "Sync" in the Company Portal immediately forces a remediation run. While a sync updates the *policy* (downloading the script package), the *execution* of that script depends on the schedule defined within the package itself.

### **1.2 The Dual-Script Architecture**

The defining characteristic of Intune Remediations is the decoupling of problem identification from problem resolution. This is achieved through a dual-script architecture consisting of a **Detection Script** and a **Remediation Script**.

This separation of concerns allows for highly efficient auditing. The detection script acts as a lightweight sensor, running frequently to assess compliance. The remediation script, which may involve heavier operations (e.g., downloading files, stopping services), executes only when necessary.

**The Execution Flow:**

1. **Policy Retrieval:** The device downloads the script package containing both scripts and the schedule metadata.  
2. **Detection Phase:** The IME executes the Detection Script.  
3. **Evaluation:** The IME analyzes the Exit Code returned by the Detection Script.  
4. **Conditional Branching:**  
   * If **Exit 0**: The device is compliant. The workflow terminates, and a status of "Without Issues" is reported.  
   * If **Exit 1**: The device is non-compliant. The workflow proceeds to the Remediation Phase.  
   * If **Other**: The script is marked as failed/error.  
5. **Remediation Phase:** The IME executes the Remediation Script to fix the issue.  
6. **Verification Phase:** Immediately after the Remediation Script completes, the **Detection Script runs a second time**. This critical step verifies whether the remediation was successful.3

**Table 1: Exit Code Logic and System Behavior**

| Exit Code | Classification | System Behavior | Reporting Status |
| :---- | :---- | :---- | :---- |
| **0** | **Success / Compliant** | The condition is satisfied. Remediation is skipped. | "Without Issues" |
| **1** | **Failure / Non-Compliant** | The condition is not satisfied. Triggers Remediation Script. | "With Issues" (Pre-remediation) |
| **Other** | **Script Error** | The script failed to execute correctly (e.g., syntax error, unhandled exception). | "Failed" |

This verification loop implies that the detection script must be **idempotent**—it must produce consistent results regardless of how many times it is run, and running it should not alter the state of the system.5

### **1.3 Execution Contexts and Licensing**

The versatility of Intune Remediations is further enhanced by the ability to select the execution context. Scripts can run either as the **System** (default) or the **Logged-on User**.

* **System Context:** Used for system-wide configurations (e.g., firewall rules, software installation, HKLM registry keys). It has full local administrative rights but generally lacks access to network resources authenticated by the user.  
* **User Context:** Used for user-specific configurations (e.g., mapping network drives, modifying HKCU registry keys, changing desktop wallpaper). This context impersonates the currently logged-on user. If no user is logged in, these scripts will typically fail or not run until a session is active.1

Licensing Requirements:  
It is imperative to note that Remediations is an enterprise feature. Access requires Windows Enterprise E3/E5 or Education A3/A5 licensing. It is typically not included in the standard Business Premium SKU without add-ons, which is a frequent point of confusion for small-to-medium business architects.1

## ---

**2\. Developing Robust Detection Logic**

The detection script is the foundation of the entire remediation workflow. A flaw in detection logic can lead to "compliance flapping," where a device oscillates between states, or "remediation storms," where a script repeatedly attempts to fix an issue that cannot be resolved, consuming system resources and generating log noise.

### **2.1 The Philosophy of Deterministic Detection**

A detection script must be binary and deterministic. It must strictly evaluate whether a specific condition exists or does not exist. Ambiguity is the enemy of automation.

**Poor Detection Logic Example:**

* *Check:* "Is Google Chrome installed?"  
* *Implementation:* Checking for the existence of chrome.exe.  
* *Flaw:* This ignores the *version* of the browser. If the goal is to enforce a specific security baseline, simply checking for the file's presence is insufficient. The device might have an outdated, vulnerable version but still return "Compliant" (Exit 0\) because the file exists.

**Robust Detection Logic Example:**

* *Check:* "Is Google Chrome installed AND is it at least version 100.0?"  
* *Implementation:* Retrieve the file version of chrome.exe. Compare it numerically against the target version.  
* *Outcome:* If the version is lower, return Exit 1 (Non-compliant). If equal or higher, return Exit 0 (Compliant). This handles both the "missing app" and "outdated app" scenarios in a single logic block.7

### **2.2 Handling Output for the Console**

When the detection script runs, any text written to the Standard Output (STDOUT) stream is captured by the IME and sent to the Intune console. This output appears in the **"Pre-remediation detection output"** column.

**Architectural Constraints:**

* **Character Limit:** Intune imposes a strict limit of **2,048 characters** for script output. Any text exceeding this limit is truncated. This truncation occurs at the end of the string, meaning critical error details appended to a long log dump will be lost.1  
* **Last Writer Wins:** While the documentation suggests capturing output, observing the behavior of the IME reveals that often the final object written to the pipeline dominates the display. Architects should structure their script to emit a single, clean message at the very end of execution.11

Best Practice for Output:  
Avoid "chatty" scripts that spew verbose logs to STDOUT. Instead, reserve STDOUT for a high-level summary message intended for the Intune administrator. Detailed logs should be written to the local disk (discussed in Chapter 5).

### **2.3 Code Pattern: The Detection Template**

A standardized template ensures consistency across all remediation packages in an organization.

PowerShell

\<\#  
.SYNOPSIS  
    Standardized Detection Template  
.DESCRIPTION  
    Evaluates specific compliance criteria.  
    Returns Exit 0 for Success, Exit 1 for Failure.  
\#\>

\# 1\. Define Targets  
$TargetRegistryPath \= "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System"  
$TargetValueName    \= "EnableSmartScreen"  
$TargetValueData    \= 1

\# 2\. Initialize Logging (Local)  
$LogPath \= "$env:ProgramData\\Microsoft\\IntuneManagementExtension\\Logs\\Detect\_SmartScreen.log"  
Start-Transcript \-Path $LogPath \-Append \-Force \-ErrorAction SilentlyContinue

Write-Output "Initialization: Checking SmartScreen configuration."

try {  
    \# 3\. Perform Checks  
    if (\-not (Test-Path $TargetRegistryPath)) {  
        Write-Output "Compliance Status: Non-Compliant \- Registry Key Missing."  
        Exit 1  
    }

    $CurrentValue \= Get-ItemProperty \-Path $TargetRegistryPath \-Name $TargetValueName \-ErrorAction SilentlyContinue  
      
    if ($null \-eq $CurrentValue) {  
        Write-Output "Compliance Status: Non-Compliant \- Registry Value Missing."  
        Exit 1  
    }  
      
    if ($CurrentValue.$TargetValueName \-ne $TargetValueData) {  
        Write-Output "Compliance Status: Non-Compliant \- Value Mismatch. Current: $($CurrentValue.$TargetValueName), Expected: $TargetValueData"  
        Exit 1  
    }

    \# 4\. Success State  
    Write-Output "Compliance Status: Compliant \- Configuration matches target."  
    Exit 0

} catch {  
    \# 5\. Error Handling  
    \# Catch unexpected script errors (e.g., permissions issues)  
    Write-Output "Script Error: $($\_.Exception.Message)"  
    Exit 1 \# Fail-safe to Non-Compliant to ensure visibility  
} finally {  
    Stop-Transcript  
}

*Analysis of the Template:*

* **Explicit Exit Codes:** Every path results in a specific Exit 0 or Exit 1\.  
* **Structured Output:** The Write-Output messages are designed to be human-readable in the Intune console columns.3  
* **Fail-Safe:** The catch block returns Exit 1\. If the script crashes, it is better to flag the device as potentially non-compliant (triggering a remediation attempt or at least an alert) than to silently ignore the failure.

## ---

**3\. Engineering Remediation Logic**

The remediation script is the active agent of change. Because it runs autonomously, often with SYSTEM privileges, it must be engineered with defensive programming principles to prevent accidental damage.

### **3.1 Scope and Side Effects**

The cardinal rule of remediation scripting is **minimalism**. The script should correct the specific deviation found by the detection script and nothing more.

* **Avoid Reboots:** Unless the setting strictly requires a reboot to take effect (e.g., renaming a computer), avoid Restart-Computer. If a reboot is necessary, it is often better to exit and allow the Intune reboot coordination policy to handle it, or use exit codes that signal a pending reboot (though Intune Remediations currently treat non-zero exits mostly as failures).1  
* **User Interaction:** Running as SYSTEM means no UI is visible to the user. Do not use Read-Host or pop-up message boxes that block execution, as the script will hang indefinitely until it times out.1

### **3.2 Error Handling and Resilience**

Remediation scripts operate in a "headless" mode. Comprehensive error handling is mandatory.

* **Try/Catch/Finally:** Every major action (file copy, registry write, service start) should be wrapped in error handling blocks.  
* **Idempotency in Remediation:** Just like detection, remediation should be safe to run multiple times. If the script attempts to create a folder, it should first check if the folder exists or use \-Force, ensuring it doesn't error out if the folder was created by another process milliseconds earlier.

### **3.3 The Post-Remediation Feedback Loop**

A common misconception is that the output of the remediation script is what validates the fix. In reality, the **Detection Script** is the validator.

1. **Remediation Runs:** The script applies the fix. It writes "Fix Applied" to STDOUT.  
2. **Detection Re-runs:** The IME immediately runs the detection script again.  
3. **Final Status:**  
   * If Detection returns Exit 0: The remediation is deemed "Success." The output from the *Detection* script (not necessarily the remediation script) is logged as the post-remediation state.  
   * If Detection returns Exit 1: The remediation is deemed "Failed." The issue persists.4

This architecture dictates that your remediation script does not strictly *need* to verify its own work, as the detection script will do it anyway. However, self-verification within the remediation script is good practice for detailed local logging.

**Table 2: Output Column Sources**

| Console Column | Source Script | Trigger Condition |
| :---- | :---- | :---- |
| **Pre-remediation detection output** | Detection Script | Runs first. Populated if Exit Code is 1\. |
| **Remediation script error** | Remediation Script | Populated if the remediation script throws a terminating error or writes to STDERR. |
| **Post-remediation detection output** | Detection Script | Runs *after* remediation. Shows the final state (ideally "Compliant"). |

### **3.4 Handling External Dependencies**

Sophisticated remediations often require external files (e.g., an installer .msi or a config file).

* **Avoid Internet Dependency:** Where possible, embed small configuration data directly in the script.  
* **Secure Downloads:** If downloading from an external source (Azure Blob, GitHub), use Invoke-WebRequest with rigorous error checking. Ensure the URL is HTTPS.  
* **Integrity Checks:** Always verify the hash (Get-FileHash) of a downloaded file before executing it to prevent supply-chain attacks or corrupted downloads.

## ---

**4\. Advanced Logging and Observability Strategy**

One of the most significant challenges in managing endpoints at scale is visibility. When a remediation fails on 500 devices, the generic "Failed" status in the Intune console is insufficient for root cause analysis. A robust logging strategy is non-negotiable for enterprise deployments.

### **4.1 The Limitations of Native Reporting**

The Intune console provides a "Device Status" view, but it has limitations:

* **Latency:** Reporting is not real-time. There can be significant delays between script execution and console updates.  
* **Truncation:** The 2,048-character limit means that extensive error stacks or verbose logs will be cut off, often removing the most critical information at the end of the message.10  
* **Retention:** Intune does not provide long-term historical log retention for script executions.

### **4.2 The Local Logging Standard**

To overcome these limitations, scripts must implement their own logging on the local device. The industry-standard location for these logs is C:\\ProgramData\\Microsoft\\IntuneManagementExtension\\Logs\\.

* **Why this path?** It is the native directory for the IME. Support engineers and administrators are already trained to look here. It is also secured by default (writable by SYSTEM/Admin, readable by Admin).  
* **Naming Convention:** Use a consistent naming convention, e.g., Remediation-.log.

### **4.3 Implementing Start-Transcript**

PowerShell’s Start-Transcript cmdlet is the most effective tool for capturing script activity. It records all output to the console, including Write-Output, Write-Warning, and Write-Error, as well as command invocations.

**Best Practice Implementation:**

PowerShell

$LogPath \= "$env:ProgramData\\Microsoft\\IntuneManagementExtension\\Logs\\Remediation\_FirewallFix.log"  
try {  
    Start-Transcript \-Path $LogPath \-Append \-Force \-ErrorAction SilentlyContinue  
    \#... Script Logic...  
} finally {  
    Stop-Transcript  
}

Using \-Append ensures that historical execution data is preserved, allowing analysts to see if a script has failed repeatedly over time.12

### **4.4 Automated Log Rotation**

A critical risk with local logging is disk consumption. If a remediation runs hourly and appends to a log file indefinitely, that file can grow to consume gigabytes, potentially filling the system drive. The IME does not rotate custom script logs. Therefore, the script itself must handle its own hygiene.

The Self-Cleaning Log Pattern:  
Every script should include a lightweight function to check the log size before writing. If the log exceeds a threshold (e.g., 5MB), it should be archived or cleared.

PowerShell

Function Manage-LogRotation {  
    Param (  
        \[string\]$Path,  
        \[int\]$MaxSizeMB \= 5,  
        \[int\]$MaxHistory \= 3  
    )  
      
    if (Test-Path $Path) {  
        $LogFile \= Get-Item $Path  
        if ($LogFile.Length \-gt ($MaxSizeMB \* 1MB)) {  
            Write-Output "Log Rotation: File size $($LogFile.Length) bytes exceeds limit. Rotating."  
              
            \# Archive current log  
            $Timestamp \= Get-Date \-Format "yyyyMMdd-HHmmss"  
            $ArchiveName \= "$($Path).$Timestamp.old"  
            Rename-Item \-Path $Path \-NewName $ArchiveName \-Force  
              
            \# Prune old logs  
            $ParentDir \= Split-Path $Path \-Parent  
            $BaseName \= Split-Path $Path \-Leaf  
            $OldLogs \= Get-ChildItem \-Path $ParentDir \-Filter "$BaseName.\*.old" | Sort-Object LastWriteTime \-Descending  
              
            if ($OldLogs.Count \-gt $MaxHistory) {  
                $OldLogs | Select-Object \-Skip $MaxHistory | Remove-Item \-Force  
                Write-Output "Log Rotation: Removed $($OldLogs.Count \- $MaxHistory) old archives."  
            }  
        }  
    }  
}

*Why this is crucial:* This functionality ensures that the remediation mechanism—intended to fix the device—does not become the cause of a new problem (disk exhaustion).15

### **4.5 Centralized Logging via HTTP Data Collector (Azure Monitor)**

For organizations requiring real-time visibility across thousands of devices, local logs are insufficient. A more advanced pattern involves sending script results directly to an Azure Log Analytics workspace using the HTTP Data Collector API.

**Architecture:**

1. **Azure Setup:** Create a Log Analytics Workspace in Azure. Obtain the Workspace ID and Primary Key.  
2. **Script Logic:** Construct a JSON payload containing the device name, script name, status, and error details.  
3. **Transmission:** Use Invoke-RestMethod to POST this payload to the Azure Monitor API.

*Note on Security:* This method requires embedding the Workspace Key in the script or retrieving it securely. Embedding keys is generally discouraged. A more secure approach uses an Azure Function as an intermediary or leverages Certificate-based authentication if the infrastructure supports it. However, for many organizations, the "Log Analytics" approach provides unmatched observability into remediation trends.18

## ---

**5\. Sending Status to Intune: Reporting Mechanics**

While local logs are for engineers, the Intune Console is for management. Ensuring the data presented there is accurate and meaningful is a key requirement.

### **5.1 Utilizing Standard Output (STDOUT)**

As established, Intune scrapes STDOUT for status. The challenge is making this text useful within the 2,048-character constraint.

Formatting for Readability:  
Instead of dumping raw data, format the output to be easily readable in the narrow columns of the web console.

* *Bad:* Error 0x80004005 System.IO.FileNotFoundException at...  
* *Good:* \[Path: C:\\App\\Conf.xml\] \- See local log for stack trace.

### **5.2 Structured Data (JSON) for Graph API Consumption**

While the console displays text, the backend stores the full output string. By outputting **JSON** instead of plain text, administrators can perform powerful data extraction later using the Microsoft Graph API.

The JSON Output Strategy:  
If a script outputs a JSON string, the console will simply display that JSON. This might look messy to a human eye in the web portal, but it allows automated tools (Power BI, custom dashboards) to parse the field.

PowerShell

\# Construct a custom object with all relevant details  
$StatusObj \=@{  
    ComplianceState \= "NonCompliant"  
    MissingKB       \= "KB5001234"  
    LastPatchDate   \= "2023-10-01"  
    DiskSpaceFreeGB \= 45  
}

\# Output compressed JSON to save characters  
Write-Output ($StatusObj | ConvertTo-Json \-Compress)  
Exit 1

By using \-Compress, you maximize the data density within the 2,048 limit. An administrator can then use a Graph API call (GET /deviceManagement/deviceHealthScripts/{id}/deviceRunStates) to retrieve these JSON blobs across the fleet and visualize them, creating a custom "Compliance Dashboard" that goes far beyond simple "Success/Fail" metrics.19

### **5.3 Diagnostic Data Collection**

The "Device Status" blade in Intune also allows for "Collect Diagnostics." This triggers the device to zip up logs from the ProgramData location (where we stored our logs in Section 4.2) and upload them to the cloud. This seamless integration reinforces the importance of storing custom transcripts in the standard IME log directory.14

## ---

**6\. Security, Compliance, and Code Signing**

Allowing scripts to run automatically with SYSTEM privileges is a high-stakes capability. If compromised, this mechanism could be used to deploy malware or exfiltrate data. Security controls must be rigorous.

### **6.1 Execution Policies and the "Bypass" Trap**

By default, if the "Enforce script signature check" option is set to **No** in the remediation profile, the IME executes scripts using the Bypass execution policy. This overrides the local machine's policy (even if set to Restricted) and allows any script to run. While convenient, this is a security risk.

### **6.2 Implementing Code Signing (Authenticode)**

For high-security environments (government, finance), the **"Enforce script signature check"** option should be enabled. This forces the IME to validate the digital signature of the script before execution.

**Prerequisites for Enforcement:**

1. **Certificate Trust:** The certificate used to sign the script must be trusted by the device. This means the Root CA must be in the "Trusted Root Certification Authorities" store, and the code-signing certificate itself (or its issuer) must be in the **"Trusted Publishers"** store.1  
2. **Encoding:** Signed scripts **must be encoded in UTF-8** (without BOM). The Byte Order Mark (BOM) can interfere with the signature block hash verification in some contexts.1  
3. **Local Policy:** The device's PowerShell execution policy must be set to AllSigned or RemoteSigned. If the local policy is Restricted, even signed scripts may fail depending on how the IME invokes the session.

**The Signing Workflow:**

1. **Obtain Certificate:** Issue a Code Signing certificate from the internal PKI or a public CA.  
2. **Sign the Script:** Use the Set-AuthenticodeSignature cmdlet.  
   PowerShell  
   $Cert \= Get-ChildItem Cert:\\CurrentUser\\My \-CodeSigningCert | Select-Object \-First 1  
   Set-AuthenticodeSignature \-FilePath "C:\\Repo\\Remediation.ps1" \-Certificate $Cert

3. **Deploy Certificate:** Use an Intune Configuration Profile (Trusted Certificate) to push the public key to the Trusted Publishers store on all endpoints.22

### **6.3 Handling Secrets**

Remediation scripts should never contain hardcoded secrets (passwords, API keys). Scripts are cached on the client device in the IME working directories (often C:\\ProgramData\\Microsoft\\IntuneManagementExtension\\Policies\\Scripts) and can be recovered by any local administrator.

* **Alternative:** Use Managed Identities if accessing Azure resources. Use certificate-based authentication where the certificate is securely deployed to the machine store.

### **6.4 Privacy Considerations (GDPR)**

Scripts often gather data to determine compliance. Administrators must ensure that detection scripts do not harvest Personally Identifiable Information (PII) and output it to the Intune console. The "Pre-remediation detection output" is visible to anyone with Intune Reader rights. Logging user browsing history or file contents here is a privacy violation. Keep output strictly technical (e.g., "File hash mismatch" rather than "User has file X on desktop").1

## ---

**7\. Operationalization and Lifecycle Management**

Moving from ad-hoc scripting to a mature DevOps capability requires treating remediation scripts as software products.

### **7.1 Version Control (Git)**

Do not manage scripts by saving .ps1 files in a local folder. All remediation scripts should be stored in a Version Control System (VCS) like GitHub or Azure DevOps.

* **Benefits:** Change tracking, peer review (Pull Requests), and rollback capabilities.  
* **Structure:** Organize the repo by remediation package, keeping the Detection and Remediation scripts together.  
  /Repo  
    /Remediation-FixPrintSpooler  
      Detect.ps1  
      Remediate.ps1  
      ReadMe.md  
    /Remediation-UpdateBios  
      Detect.ps1  
      Remediate.ps1

### **7.2 CI/CD Deployment via Graph API**

Advanced organizations automate the deployment of these scripts. Using GitHub Actions or Azure DevOps Pipelines, a commit to the main branch can trigger a pipeline that uses the Microsoft Graph API to update the script package in Intune automatically.

* **API Endpoint:** deviceManagement/deviceHealthScripts  
* **Workflow:**  
  1. Developer commits change to Detect.ps1.  
  2. Pipeline triggers.  
  3. Pipeline reads the script content, encodes it to Base64.  
  4. Pipeline authenticates to Graph API.  
  5. Pipeline PATCHes the existing script entity with the new content.25

This eliminates the manual, error-prone process of uploading files via the web browser.

### **7.3 Scheduling Strategy**

The schedule of a remediation significantly impacts the fleet's performance.

* **Hourly:** High impact. Use only for critical security controls (e.g., "Is the DLP agent running?").  
* **Daily:** Standard impact. Suitable for most configuration drift checks.  
* **Once:** Zero recurrence. Use for one-time migrations (e.g., "Uninstall Legacy App X"). Note that "Once" scripts run immediately upon policy receipt.1

Staggering and Randomization:  
Unlike Group Policy, Intune policy processing is inherently somewhat staggered due to the polling intervals of the agents. However, for resource-intensive remediations (e.g., those that trigger a heavy scan), consider adding a random sleep delay (Start-Sleep \-Seconds (Get-Random \-Minimum 1 \-Maximum 300)) at the start of the script to prevent "thundering herd" issues on network resources if all devices happen to sync simultaneously (e.g., after a widespread power outage).

## ---

**8\. Real-World Scenarios and Case Studies**

To contextualize these architectural principles, we examine common use cases where Intune Remediations excel.

### **Scenario A: Enforcing a Registry Configuration (Security Baseline)**

**Objective:** Ensure the "TLS 1.0" protocol is disabled in the registry for security compliance.

* **Detection:** Query HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.0\\Client. Check if Enabled is 0\.  
  * *Exit 1* if key missing or value is not 0\.  
  * *Exit 0* if value is 0\.  
* **Remediation:** Create the key structure if missing. Set Enabled to 0\.  
* **Context:** Runs as SYSTEM. Logged to C:\\ProgramData....

### **Scenario B: Application Health Check (Self-Healing)**

**Objective:** Ensure the "Corporate VPN" service is running.

* **Detection:** Get-Service \-Name "CorpVPN". Check Status.  
  * *Exit 1* if Status is 'Stopped'.  
  * *Exit 0* if Status is 'Running'.  
* **Remediation:** Start-Service \-Name "CorpVPN".  
* **Nuance:** The remediation should also check if the service is set to 'Disabled' and enable it first. It should handle dependencies.

### **Scenario C: Clearing Stale Data (Disk Hygiene)**

**Objective:** Delete temp files older than 7 days from C:\\Temp.

* **Detection:** Check if any files in C:\\Temp have a LastWriteTime \> 7 days.  
  * *Exit 1* if count \> 0\.  
  * *Exit 0* if count \== 0\.  
* **Remediation:** Get-ChildItem... | Remove-Item \-Force.  
* **Logging:** The log file should record exactly which files were deleted for audit purposes.

## ---

**9\. Conclusion**

Microsoft Intune Remediations offers a powerful, flexible framework for enforcing device state, but its power requires disciplined engineering. By adhering to the best practices outlined in this report—specifically the use of deterministic detection logic, robust local logging frameworks, structured status reporting, and secure execution contexts—administrators can transform their endpoint management from a reactive struggle into a proactive, self-healing ecosystem.

The shift to this model reduces support ticket volume, improves security posture by minimizing the window of vulnerability (configuration drift), and ensures a consistent user experience. As the digital estate continues to grow in complexity, the ability to script reliable, automated fixes will remain a differentiating skill for the modern systems architect.

## ---

**10\. Appendix: Comprehensive Code Templates**

### **10.1 Master Detection Script Template**

PowerShell

\<\#  
.SYNOPSIS  
    Enterprise Detection Script Template for Intune.  
.DESCRIPTION  
    Standardized template including logging, rotation, and exit code logic.  
\#\>

\# \--- CONFIGURATION BLOCK \---  
$AppName        \= "AppConfigAudit"  
$LogDir         \= "$env:ProgramData\\Microsoft\\IntuneManagementExtension\\Logs"  
$LogFile        \= "$LogDir\\Detect\_$AppName.log"  
$MaxLogSizeMB   \= 2  
$MaxLogHistory  \= 3

\# \--- HELPER FUNCTIONS \---  
Function Rotate-Log {  
    Param (\[string\]$Path, \[int\]$SizeLimitMB, \[int\]$HistoryLimit)  
    if (Test-Path $Path) {  
        $File \= Get-Item $Path  
        if ($File.Length \-gt ($SizeLimitMB \* 1MB)) {  
            $Archive \= "$Path.$(Get-Date \-Format 'yyyyMMdd-HHmmss').old"  
            Rename-Item \-Path $Path \-NewName $Archive \-Force  
            $OldFiles \= Get-ChildItem \-Path (Split-Path $Path) \-Filter "$(Split-Path $Path \-Leaf)\*.old" | Sort LastWriteTime \-Desc  
            if ($OldFiles.Count \-gt $HistoryLimit) { $OldFiles | Select \-Skip $HistoryLimit | Remove-Item \-Force }  
        }  
    }  
}

\# \--- MAIN EXECUTION \---  
try {  
    \# Initialize Logging  
    if (\-not (Test-Path $LogDir)) { New-Item \-Path $LogDir \-ItemType Directory \-Force | Out-Null }  
    Rotate\-Log \-Path $LogFile \-SizeLimitMB $MaxLogSizeMB \-HistoryLimit $MaxLogHistory  
    Start-Transcript \-Path $LogFile \-Append \-Force \-ErrorAction SilentlyContinue

    Write-Output "$(Get-Date): Starting Detection for $AppName"

    \# \--- DETECTION LOGIC START \---  
      
    \# Example: Check Registry  
    $RegPath \= "HKLM:\\SOFTWARE\\Corp\\Policy"  
    $RegName \= "EnforcePolicy"  
    $Expected \= 1  
      
    if (\-not (Test-Path $RegPath)) {  
        Write-Output "Status: Non-Compliant. Registry path missing."  
        Exit 1  
    }  
      
    $Current \= Get-ItemProperty \-Path $RegPath \-Name $RegName \-ErrorAction SilentlyContinue  
    if ($null \-eq $Current) {  
        Write-Output "Status: Non-Compliant. Value missing."  
        Exit 1  
    }  
      
    if ($Current.$RegName \-ne $Expected) {  
        Write-Output "Status: Non-Compliant. Value mismatch (Got: $($Current.$RegName), Expected: $Expected)."  
        Exit 1  
    }  
      
    \# \--- DETECTION LOGIC END \---

    Write-Output "Status: Compliant. Configuration matches."  
    Exit 0

} catch {  
    Write-Error "CRITICAL: Script execution failed. $($\_.Exception.Message)"  
    Exit 1 \# Fail safe  
} finally {  
    Stop-Transcript  
}

### **10.2 Master Remediation Script Template**

PowerShell

\<\#  
.SYNOPSIS  
    Enterprise Remediation Script Template for Intune.  
.DESCRIPTION  
    Standardized template for applying fixes safely.  
\#\>

\# \--- CONFIGURATION BLOCK \---  
$AppName        \= "AppConfigAudit"  
$LogDir         \= "$env:ProgramData\\Microsoft\\IntuneManagementExtension\\Logs"  
$LogFile        \= "$LogDir\\Remediate\_$AppName.log"  
$MaxLogSizeMB   \= 2

\# \--- MAIN EXECUTION \---  
try {  
    \# Initialize Logging (Simplified rotation for brevity)  
    if (\-not (Test-Path $LogDir)) { New-Item \-Path $LogDir \-ItemType Directory \-Force | Out-Null }  
    Start-Transcript \-Path $LogFile \-Append \-Force \-ErrorAction SilentlyContinue

    Write-Output "$(Get-Date): Starting Remediation for $AppName"

    \# \--- REMEDIATION LOGIC START \---  
      
    $RegPath \= "HKLM:\\SOFTWARE\\Corp\\Policy"  
    $RegName \= "EnforcePolicy"  
    $Expected \= 1

    if (\-not (Test-Path $RegPath)) {  
        New-Item \-Path $RegPath \-Force | Out-Null  
        Write-Output "Created registry path."  
    }  
      
    Set-ItemProperty \-Path $RegPath \-Name $RegName \-Value $Expected \-Force  
    Write-Output "Updated registry value to $Expected."  
      
    \# \--- REMEDIATION LOGIC END \---

    Write-Output "Remediation completed successfully."  
    Exit 0

} catch {  
    Write-Error "CRITICAL: Remediation failed. $($\_.Exception.Message)"  
    Exit 1  
} finally {  
    Stop-Transcript  
}

#### **Works cited**

1. Use Remediations to Detect and Fix Support Issues \- Microsoft Intune, accessed December 20, 2025, [https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)  
2. Remediation Script Intune \- Basics \- Part 1 \- YouTube, accessed December 20, 2025, [https://www.youtube.com/watch?v=rvawYyVP3Lk](https://www.youtube.com/watch?v=rvawYyVP3Lk)  
3. Intune Remediations: How to Automate Issue Resolution \- Insentra, accessed December 20, 2025, [https://www.insentragroup.com/nz/insights/geek-speak/modern-workplace/intune-remediations-automate-issue-resolution/](https://www.insentragroup.com/nz/insights/geek-speak/modern-workplace/intune-remediations-automate-issue-resolution/)  
4. Frank-GTH/Intune-Winget: Winget Proactive Remediation \- GitHub, accessed December 20, 2025, [https://github.com/Frank-GTH/Intune-Winget](https://github.com/Frank-GTH/Intune-Winget)  
5. How to use Intune Remediation script \- System Center Dudes, accessed December 20, 2025, [https://www.systemcenterdudes.com/how-to-use-intune-remediation-script/](https://www.systemcenterdudes.com/how-to-use-intune-remediation-script/)  
6. Endpoint analytics | Proactive Remediation \- Exit Code problem, accessed December 20, 2025, [https://www.reddit.com/r/Intune/comments/12yaszz/endpoint\_analytics\_proactive\_remediation\_exit/](https://www.reddit.com/r/Intune/comments/12yaszz/endpoint_analytics_proactive_remediation_exit/)  
7. Demystifying Intune Custom App Detection Scripts \- Andrew Taylor, accessed December 20, 2025, [https://andrewstaylor.com/2022/04/19/demystifying-intune-custom-app-detection-scripts/](https://andrewstaylor.com/2022/04/19/demystifying-intune-custom-app-detection-scripts/)  
8. Microsoft Intune PowerShell Detection scripts, accessed December 20, 2025, [https://powershellisfun.com/2023/11/30/microsoft-intune-powershell-detection-scripts/](https://powershellisfun.com/2023/11/30/microsoft-intune-powershell-detection-scripts/)  
9. Query about Intune Proactive Remediation Script Output in Device ..., accessed December 20, 2025, [https://learn.microsoft.com/en-us/answers/questions/1479426/query-about-intune-proactive-remediation-script-ou](https://learn.microsoft.com/en-us/answers/questions/1479426/query-about-intune-proactive-remediation-script-ou)  
10. Pre-remediation detection output multi-line formatting : r/Intune, accessed December 20, 2025, [https://www.reddit.com/r/Intune/comments/139mhpe/proactive\_remediations\_preremediation\_detection/](https://www.reddit.com/r/Intune/comments/139mhpe/proactive_remediations_preremediation_detection/)  
11. Query about Intune Proactive Remediation Script Output in Device ..., accessed December 20, 2025, [https://techcommunity.microsoft.com/discussions/microsoft-intune/query-about-intune-proactive-remediation-script-output-in-device-status/4025828](https://techcommunity.microsoft.com/discussions/microsoft-intune/query-about-intune-proactive-remediation-script-output-in-device-status/4025828)  
12. Troubleshooting and Logging Intune Remediations \- Mobile Jon's Blog, accessed December 20, 2025, [https://mobile-jon.com/2025/02/24/troubleshooting-and-logging-intune-remediations/](https://mobile-jon.com/2025/02/24/troubleshooting-and-logging-intune-remediations/)  
13. Start-Transcript (Microsoft.PowerShell.Host), accessed December 20, 2025, [https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.host/start-transcript?view=powershell-7.5](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.host/start-transcript?view=powershell-7.5)  
14. PSA: Where to write your Intune logs \- James Vincent, accessed December 20, 2025, [https://jamesvincent.co.uk/2024/01/23/psa-where-to-write-your-intune-logs/](https://jamesvincent.co.uk/2024/01/23/psa-where-to-write-your-intune-logs/)  
15. Native logs rotation in Windows with a simple PowerShell script, accessed December 20, 2025, [https://forum.storj.io/t/native-logs-rotation-in-windows-with-a-simple-powershell-script/6241](https://forum.storj.io/t/native-logs-rotation-in-windows-with-a-simple-powershell-script/6241)  
16. Automate Log File Rotation and Disk Space Reporting | NinjaOne, accessed December 20, 2025, [https://www.ninjaone.com/blog/automate-log-file-rotation-and-disk-space-reporting/](https://www.ninjaone.com/blog/automate-log-file-rotation-and-disk-space-reporting/)  
17. Logging in powershell with log rotation \- GitHub Gist, accessed December 20, 2025, [https://gist.github.com/barsv/85c93b599a763206f47aec150fb41ca0](https://gist.github.com/barsv/85c93b599a763206f47aec150fb41ca0)  
18. Enhance Intune Inventory data with Proactive Remediations and ..., accessed December 20, 2025, [https://msendpointmgr.com/2021/04/12/enhance-intune-inventory-data-with-proactive-remediations-and-log-analytics/](https://msendpointmgr.com/2021/04/12/enhance-intune-inventory-data-with-proactive-remediations-and-log-analytics/)  
19. Create a JSON file for custom compliance settings in Microsoft Intune, accessed December 20, 2025, [https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-custom-json](https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-custom-json)  
20. Create a Proactive remediations script package \- smsagent.blog, accessed December 20, 2025, [https://docs.smsagent.blog/microsoft-endpoint-manager-reporting/gathering-custom-inventory-with-intune/create-a-proactive-remediations-script-package](https://docs.smsagent.blog/microsoft-endpoint-manager-reporting/gathering-custom-inventory-with-intune/create-a-proactive-remediations-script-package)  
21. Support tip: Learn how to simplify JSON file creation for custom ..., accessed December 20, 2025, [https://techcommunity.microsoft.com/blog/intunecustomersuccess/support-tip-learn-how-to-simplify-json-file-creation-for-custom-compliance/3627462](https://techcommunity.microsoft.com/blog/intunecustomersuccess/support-tip-learn-how-to-simplify-json-file-creation-for-custom-compliance/3627462)  
22. Set-AuthenticodeSignature (Microsoft.PowerShell.Security), accessed December 20, 2025, [https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-authenticodesignature?view=powershell-7.5](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-authenticodesignature?view=powershell-7.5)  
23. Sign Remediation Scripts for Testing Purposes \- Help Aternity, accessed December 20, 2025, [https://help.aternity.com/bundle/console\_admin\_guide\_x\_console\_saas/page/console/topics/admin\_remedy\_selfsignscripts.html](https://help.aternity.com/bundle/console_admin_guide_x_console_saas/page/console/topics/admin_remedy_selfsignscripts.html)  
24. Code signature for PowerShell script files \- Uwe Gradenegger, accessed December 20, 2025, [https://www.gradenegger.eu/en/code-signature-for-powershell-script-files/](https://www.gradenegger.eu/en/code-signature-for-powershell-script-files/)  
25. Manage Intune Scripts With GitHub Actions, accessed December 20, 2025, [https://rozemuller.com/manage-intune-scripts-with-github-actions/](https://rozemuller.com/manage-intune-scripts-with-github-actions/)  
26. Creating Intune Proactive Remediation via Powershell \- Andrew Taylor, accessed December 20, 2025, [https://andrewstaylor.com/2022/06/20/creating-intune-proactive-remediation-via-powershell/](https://andrewstaylor.com/2022/06/20/creating-intune-proactive-remediation-via-powershell/)