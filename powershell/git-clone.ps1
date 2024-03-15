<#
.SYNOPSIS
This script ensures the latest version of a specified Git repository is installed and updated on the local system.

.DESCRIPTION
The script performs the following actions:
- Checks for and installs the latest version of Git if it's not already installed.
- Installs necessary PowerShell modules (PackageManagement, AWSPowerShell, PendingReboot).
- Determines the best available drive (prefers D:\ over C:\) to store the repository.
- Clones the repository to the specified location if it's not already present, or pulls the latest changes if it is.

.PARAMETER repoUrl
The URL of the Git repository to clone or pull. Default value is 'https://github.com/IT-Surgery/Scripts.git'.

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

# Create the logs directory if it does not exist
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

# Define the log file name with current date and time
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "Git-Clone-$dateTime.log"
$logFilePath = Join-Path -Path $logPath -ChildPath $logFile

# Function to write output to both console and log file
function Write-Log {
    Param ([string]$Message)
    Write-Output $Message
    $Message | Out-File -FilePath $logFilePath -Append -Encoding UTF8
}

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

Write-Log "Install the latest version of GIT"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
    $downloadUrl = ($latestRelease.assets | Where-Object { $_.name -like '*64-bit.exe' }).browser_download_url
    $installerPath = "$env:TEMP\GitInstaller.exe"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
    Start-Process -Wait -FilePath $installerPath -ArgumentList "/VERYSILENT"
    Remove-Item -Path $installerPath -Force
} else {
    Write-Log "Git is already installed. Version: $(git --version)"
}
git --version | Out-File -FilePath $logFilePath -Append -Encoding UTF8

# Determine the save location based on the availability of the D:\ drive
$drive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$repoName = $repoUrl -split '/' | Select-Object -Last 1 -Skip 1
$saveLocation = Join-Path -Path $drive -ChildPath ("Git\" + $repoName.Replace('.git', ''))

# Clone or pull the repository
if (Test-Path $saveLocation) {
    Write-Log "Updating the repository at $saveLocation"
    Set-Location -Path $saveLocation
    git pull | Out-File -FilePath $logFilePath -Append -Encoding UTF8
} else {
    Write-Log "Cloning the repository to $saveLocation"
    git clone $repoUrl $saveLocation | Out-File -FilePath $logFilePath -Append -Encoding UTF8
}
