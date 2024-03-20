<#
.SYNOPSIS
Efficient script to ensure a fresh copy of a specified Git repository is downloaded.

.DESCRIPTION
- Checks and installs Git if not present.
- Manages separate log files for different operations.
- Installs necessary PowerShell modules.
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

function Write-Log {
    Param ([string]$Message, [string]$LogFilePath)
    Write-Output $Message
    $Message | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
}

function Setup-Log {
    Param ([string]$LogSubFolder, [string]$LogPrefix)
    $LogDrive = if (Test-Path D:\) { "D:\" } else { "C:\" }
    $LogPath = Join-Path -Path $LogDrive -ChildPath $LogSubFolder
    if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
    $DateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $LogFile = "$LogPrefix-$DateTime.log"
    $LogFilePath = Join-Path -Path $LogPath -ChildPath $LogFile
    return $LogFilePath
}

function CheckAndInstallGit {
    $LogFilePath = Setup-Log "Logs\Git\" "Install-Git"
    Write-Log "Checking for Git installation" $LogFilePath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git not found. Attempting installation via Chocolatey." $LogFilePath
        Install-Chocolatey $LogFilePath
        Refresh-Path
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "Git installation failed."
        }
    }
    Write-Log "Git is installed. Version: $(git --version)" $LogFilePath
}

function Install-Chocolatey {
    Param ([string]$LogFilePath)
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "Installing Chocolatey..." $LogFilePath
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $ChocoInstallScript = (Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing).Content
        Invoke-Expression $ChocoInstallScript
        Write-Log "Chocolatey installed successfully." $LogFilePath
    }
    if (!(choco list --local-only | Select-String -Pattern "git")) {
        choco install git -y --no-progress | Out-Null
        Write-Log "Git package installed via Chocolatey." $LogFilePath
    }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-PowerShellModules {
    $LogFilePath = Setup-Log "Logs\PowerShell\" "PowerShell-Modules-Install"
    $Modules = 'PackageManagement', 'PendingReboot'
    foreach ($Module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            Install-Module -Name $Module -SkipPublisherCheck -Force
            Import-Module $Module
            Write-Log "Installed and imported module $Module." $LogFilePath
        }
    }
}

# Main Script
$repoUrl = 'https://github.com/IT-Surgery/Scripts.git'

CheckAndInstallGit
Install-PowerShellModules

# Clone Repository
$LogFilePath = Setup-Log "Logs\Git\" "Git-Clone"
$Drive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$urlParts = $repoUrl -split '/'
$repoOwner = $urlParts[-2]
$repoName = $urlParts[-1] -replace '\.git$', ''
$saveLocation = Join-Path -Path $Drive -ChildPath "Git\$repoOwner\$repoName"

if (Test-Path $saveLocation) {
    Write-Log "Repository exists at $saveLocation. Deleting for a fresh clone." $LogFilePath
    Remove-Item -Path $saveLocation -Recurse -Force
}

Write-Log "Cloning repository to $saveLocation" $LogFilePath
git clone $repoUrl $saveLocation 2>&1 | Out-File -FilePath $LogFilePath -Append -Encoding utf8
