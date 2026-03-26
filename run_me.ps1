$adminPass = Read-Host "Admin password" -AsSecureString
$userPass  = Read-Host "Standard user password" -AsSecureString

$params = @{
    LocalAdminUser = "LocalAdmin"
    LocalAdminPassword = $adminPass
    StandardUser = "Operator"
    StandardUserPassword = $userPass
    ConfigPath = ".\config.ini"
}

.\Invoke-BaselineProvisioning.ps1 @params