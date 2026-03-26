# Базовий provisioning

- Create local admin (separate account, not daily use)
- Create standard user (primary work account)
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

- Set Software Restriction Policies default security level to Disallowed
- Allow execution from C:\Windows\*
- Allow execution from C:\Program Files\*
- Allow execution from C:\Program Files (x86)\*
- Block execution from %USERPROFILE%\Downloads\*
- Block execution from %USERPROFILE%\Desktop\*
- Block execution from %TEMP%\*

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

# How to run

$adminPass = Read-Host "Admin password" -AsSecureString
$userPass  = Read-Host "Standard user password" -AsSecureString

.\baseline-provisioning.ps1 `
  -LocalAdminUser "LocalAdmin" `
  -LocalAdminPassword $adminPass `
  -StandardUser "Operator" `
  -StandardUserPassword $userPass `
  -EnableBitLocker `
  -EnableControlledFolderAccess `
  -ConfigureOfficePolicies `
  -ConfigureSRP


# Перед запуском перевірити:

BitLocker: enabled
Defender: real-time protection ON
UAC: enabled
user ≠ admin
updates: не відключені