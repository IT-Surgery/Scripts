<#
.SYNOPSIS
Efficient script to ensure a fresh copy of a specified Git repository is downloaded.

.DESCRIPTION
- Checks for Git and installs it if not present.
- Manages separate log files for different operations.
- Determines storage drive preference (D:\ over C:\).
- Freshly clones the specified Git repository.

.PARAMETER repoUrl
URL of the Git repository. Default: 'https://github.com/IT-Surgery/Scripts.git'.

.EXAMPLES
PS> .\UpdateGitRepo.ps1
PS> .\UpdateGitRepo.ps1 -repoUrl 'https://github.com/SomeOtherUser/OtherRepo.git'

.NOTES
Version:        1.2
Author:         IT Surgery
Creation Date:  03-20-2024
#>

# Setup Logging Function
function WriteLog {
    Param ([string]$Message, [string]$LogFilePath)
    Write-Output $Message
    $Message | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
}

function SetupLog {
    Param ([string]$LogSubFolder, [string]$LogPrefix)
    $LogDrive = if (Test-Path D:\) { "D:\" } else { "C:\" }
    $LogPath = Join-Path -Path $LogDrive -ChildPath $LogSubFolder
    if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
    $DateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $LogFile = "$LogPrefix-$DateTime.log"
    $LogFilePath = Join-Path -Path $LogPath -ChildPath $LogFile
    return $LogFilePath
}

# Main Script
$repoUrl = 'https://github.com/IT-Surgery/Scripts.git'

# Check and Install Git if necessary
$GitLogFilePath = SetupLog "Logs\Git\" "Check-Install-Git"
WriteLog "Checking for Git installation" $GitLogFilePath
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    WriteLog "Git not found. Attempting to install Git via Chocolatey." $GitLogFilePath
    # Attempt to install Chocolatey if it's not already present
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        WriteLog "Installing Chocolatey..." $GitLogFilePath
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $ChocoInstallScript = (Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing).Content
        Invoke-Expression $ChocoInstallScript
        WriteLog "Chocolatey installed successfully." $GitLogFilePath
    }
    choco install git -y --no-progress | Out-Null
    WriteLog "Git package installed via Chocolatey." $GitLogFilePath
}

# Refresh environment PATH to ensure newly installed Git can be recognized
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Install PowerShell Modules if necessary
$PwshModulesLogFilePath = SetupLog "Logs\PowerShell\" "Install-PowerShell-Modules"
Install-PackageProvider -Name NuGet -Force
$Modules = 'PackageManagement', 'PendingReboot'
foreach ($Module in $Modules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Install-Module -Name $Module -SkipPublisherCheck -Force
        Import-Module $Module
        WriteLog "Installed and imported module $Module." $PwshModulesLogFilePath
    }
}

# Clone Repository
$CloneLogFilePath = SetupLog "Logs\Git\" "Git-Clone"
$Drive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$urlParts = $repoUrl -split '/'
$repoOwner = $urlParts[-2]
$repoName = $urlParts[-1] -replace '\.git$', ''
$saveLocation = Join-Path -Path $Drive -ChildPath "Git\$repoOwner\$repoName"

if (Test-Path $saveLocation) {
    WriteLog "Repository exists at $saveLocation. Deleting for a fresh clone." $CloneLogFilePath
    Remove-Item -Path $saveLocation -Recurse -Force}

WriteLog "Cloning repository to $saveLocation" $CloneLogFilePath
git clone $repoUrl $saveLocation
if ($?) {WriteLog "Repository cloned successfully to $saveLocation." $CloneLogFilePath
} else {WriteLog "Failed to clone the repository. Check for errors in git output." $CloneLogFilePath}
