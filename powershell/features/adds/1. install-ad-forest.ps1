param(
    [string]$AdDomainName = "adds.private",
    [string]$AdNetbiosName = "ADDS",
    [string]$AdPassword = "C4ang3M3as@p01!",
    [string]$AdAdmin = "AD-Admin" # New parameter for the administrator username
)

# Function to write output to both console and log file
function Write-Log {
    param(
        [string]$Message
    )
    Write-Output $Message
    $Message | Out-File -FilePath $logPath -Append
}

# Determine log file location based on D:\ presence
$logDirectory = if (Test-Path 'D:\') { "D:\Logs\ADDS" } else { "C:\Logs\ADDS" }
if (-not (Test-Path $logDirectory)) {New-Item -ItemType Directory -Path $logDirectory -Force}
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$logPath = "$logDirectory\ADDS-Forest-Install-$currentDateTime.log"

# Convert the plain text password to a secure string
$Credential = ConvertTo-SecureString $AdPassword -AsPlainText -Force

# Determine the installation drive based on availability
$AdDisk = if (Test-Path 'D:\') { "D:\" } else { "C:\" }
$AdDbPath = "${AdDisk}ADDS\Database"
$AdLogPath = "${AdDisk}ADDS\Log"
$AdSysvolPath = "${AdDisk}ADDS\SYSVOL"

Write-Log "Checking Active Directory Domain Services (ADDS) prerequisites."

# Rest of the script remains unchanged up to the installation part...

# After Active Directory setup completion, create a new administrator user
Write-Log "Creating a new administrator user: $AdAdmin"
$AdUserCredential = ConvertTo-SecureString $AdPassword -AsPlainText -Force
New-ADUser -Name $AdAdmin -GivenName "AD" -Surname "Admin" -UserPrincipalName "$AdAdmin@$AdDomainName" -SamAccountName $AdAdmin -AccountPassword $AdUserCredential -PasswordNeverExpires $true -Enabled $true -Path "CN=Users,DC=$(($AdDomainName -split '\.')[0]),DC=$(($AdDomainName -split '\.')[1])"

Write-Log "New administrator user '$AdAdmin' created successfully."

Write-Log "Active Directory Domain Services setup has completed."
Write-Log "Rebooting to complete ADDS installation."
Start-Sleep -Seconds 5
Restart-Computer
