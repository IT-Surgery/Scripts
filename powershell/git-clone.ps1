<#
.SYNOPSIS
This script ensures a fresh copy of a specified Git repository is downloaded to the local system.

.DESCRIPTION
The script performs the following actions:
- Checks for Git installation and stops with an error if Git is not installed.
- Installs necessary PowerShell modules (PackageManagement, PendingReboot).
- Determines the best available drive (prefers D:\ over C:\) to store the repository.
- Deletes the repository if it already exists, then clones a fresh copy to the specified location.

.PARAMETER repoUrl
The URL of the Git repository to clone. Default value is 'https://github.com/IT-Surgery/Scripts.git'.

.EXAMPLE
PS> .\UpdateGitRepo.ps1
Executes the script using the default repository URL.

.EXAMPLE
PS> .\UpdateGitRepo.ps1 -repoUrl 'https://github.com/SomeOtherUser/OtherRepo.git'
Executes the script using a custom repository URL.

.NOTES
Version:        1.0
Author:         IT Surgery
Creation Date:  03-15-2024
#>

# Define the repository URL
$repoUrl = 'https://github.com/IT-Surgery/Scripts.git'

# Determine the logs directory based on the availability of the D:\ drive
$logDrive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$logPath = Join-Path -Path $logDrive -ChildPath "Logs\Git\"

# Define the log file name with current date and time
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "Git-Clone-$dateTime.log"
$logFilePath = Join-Path -Path $logPath -ChildPath $logFile

# Create the logs directory if it does not exist
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

# Logging function
function Write-Log {
    Param ([string]$Message)
    Write-Output $Message
    $Message | Out-File -FilePath $logFilePath -Append -Encoding UTF8
}

# Check if Git is installed
Write-Log "Checking for Git installation"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git must be installed to use this script."
}
Write-Log "Git is installed. Version: $(git --version)"

# Installing PowerShell Modules
Write-Log "Installing PowerShell Modules"
Install-PackageProvider -Name NuGet -Force
$modules = 'PackageManagement', 'PendingReboot'
foreach ($module in $modules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Log "Module $module is already installed."
    }
    else {
        Write-Log "Installing module $module."
        Install-Module -Name $module -SkipPublisherCheck -Force
    }
    Import-Module $module
}

# Determine the save location based on the availability of the D:\ drive
$drive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$urlParts = $repoUrl -split '/'
$repoOwner = $urlParts[-2] # The second to last element is typically the owner or organization name
$repoName = $urlParts[-1] -replace '\.git$', '' # The last element is the repository name
$saveLocation = Join-Path -Path $drive -ChildPath "Git\$repoOwner\$repoName"

# Clone or refresh the repository
if (Test-Path $saveLocation) {
    Write-Log "Repository exists at $saveLocation. Deleting for a fresh clone."
    Remove-Item -Path $saveLocation -Recurse -Force
}

Write-Log "Cloning the repository to $saveLocation"
$gitCommand = "git clone '$repoUrl' '$saveLocation' 2>&1"
Start-Process -FilePath "powershell.exe" -ArgumentList "-Command", $gitCommand -Wait -WindowStyle Hidden | Out-File -FilePath $logFilePath -Append -Encoding utf8
