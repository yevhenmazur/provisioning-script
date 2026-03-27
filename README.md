# Baseline Provisioning

## What is this?
This script is designed for the initial setup of a PC running Windows 10/11
Please see below for a full list of changes being made to the system.

## Structure

- `Start-Provisioning.cmd` - the only entry point; run as Administrator to start provisioning with no manual commands
- `Start-Provisioning.ps1` - interactive orchestrator; collects input, reads config, and runs provisioning steps
- `Invoke-BaselineProvisioning.ps1` - applies baseline configuration; non-interactive execution logic
- `Invoke-SRPRollout.ps1` - applies Software Restriction Policies; executed separately due to higher risk
- `config.ini` - default configuration and feature toggles
- `Modules/` - reusable PowerShell modules grouped by responsibility, such as users, configuration, logging, and password generation

## Modules

- `Config.psm1` - INI parser and config helpers
- `Common.psm1` - logging, admin check, registry helpers, step runner
- `Users.psm1` - local users and group membership
- `SecurityBaseline.psm1` - password policy, UAC, screen lock, auditing
- `WindowsFeatures.psm1` - firewall, updates, legacy feature disablement, time sync
- `Defender.psm1` - Defender and SmartScreen
- `BitLocker.psm1` - BitLocker enablement and recovery key export
- `Office.psm1` - Office policy baseline
- `ScriptHandling.psm1` - PowerShell execution policy and `.ps1` association
- `SRP.psm1` - SRP configuration only
- `Secrets.psm1` - secret handling

## Usage

### 1. Run baseline provisioning

Run `Start-Provisioning.cmd` as Administrator

### 2. Enable optional features through config.ini

Examples:

```ini
[BitLocker]
EnableBitLocker=true

[Defender]
EnableControlledFolderAccess=true

[Office]
ConfigureOfficePolicies=true
```

### 3. Roll out SRP separately

SRP is the setting most likely to break workstation usability. It should not share the same rollout cycle with the safer baseline settings.

```powershell
.\Invoke-SRPRollout.ps1
```

## Notes

- Reboot after baseline provisioning.
- Reboot after SRP rollout.
- Validate Office version before relying on Office policy keys. Only Office 16 and 356 are supported.

## Full list of changes

- Setup password for local admin user (not daily use)
- Create standard user (primary work account), setup strong temrary password
- Disable built-in Administrator account
- Add standard user ONLY to "Users" group

- Enable UAC
- Set UAC level to "Always notify"
- Enable Admin Approval Mode

- Enable BitLocker on OS drive
- Require TPM + PIN (if possible)
- Backup BitLocker recovery key (locally + external)

- Enable Microsoft Defender real-time protection
- Enable Microsoft Defender cloud-delivered protection
- Enable Microsoft Defender tamper protection
- Enable Microsoft Defender Controlled Folder Access (optional)

- Enable automatic Windows updates
- Disable "Pause updates"
- Set active hours for updates

- Enable Windows Firewall for all profiles
- Set default inbound traffic to block
- Set default outbound traffic to allow

- Set minimum password length to 12
- Enable password complexity
- Set account lockout threshold to 5 attempts
- Set account lockout duration to 15 minutes

- Require password on wake
- Set screen timeout to 5–10 minutes

- Disable SMBv1
- Disable PowerShell v2
- Disable Autorun/Autoplay

<!-- - Set Software Restriction Policies default security level to Disallowed
- Allow execution from C:\Windows\*
- Allow execution from C:\Program Files\*
- Allow execution from C:\Program Files (x86)\*
- Block execution from %USERPROFILE%\Downloads\*
- Block execution from %USERPROFILE%\Desktop\*
- Block execution from %TEMP%\* -->

- Disable all Office macros except digitally signed

- Disable DDE
- Disable OLE package execution

- Enable Protected View for Internet files
- Enable Protected View for Outlook attachments

- Ensure .ps1 files are not associated with double-click execution
- Set PowerShell ExecutionPolicy to RemoteSigned

- Enable Windows SmartScreen
- Block unknown applications via SmartScreen

- Enable audit logging for logon events
- Enable audit logging for process creation (Event ID 4688)

- Sync system time with reliable NTP server