<#
.SYNOPSIS
Efficient script to ensure a fresh copy of a specified Git repository is downloaded.

.DESCRIPTION
- Checks and installs Git if not present.
- Consolidates log file management.
- Installs necessary PowerShell modules.
- Determines storage drive preference (D:\ over C:\).
- Freshly clones the specified Git repository.

.PARAMETER repoUrl
URL of the Git repository. Default: 'https://github.com/IT-Surgery/Scripts.git'.

.EXAMPLES
PS> .\UpdateGitRepo.ps1
PS> .\UpdateGitRepo.ps1 -repoUrl 'https://github.com/SomeOtherUser/OtherRepo.git'

.NOTES
Version:        1.1
Author:         IT Surgery
Creation Date:  03-15-2024
#>

# Helper Functions
function Write-Log {
    Param ([string]$Message)
    Write-Output $Message
    $Message | Out-File -FilePath $global:logFilePath -Append -Encoding UTF8
}

function Setup-Log {
    Param ([string]$logSubFolder, [string]$logPrefix)
    $logDrive = if (Test-Path D:\) { "D:\" } else { "C:\" }
    $logPath = Join-Path -Path $logDrive -ChildPath $logSubFolder
    if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath -Force | Out-Null }
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = "$logPrefix-$dateTime.log"
    $logFilePath = Join-Path -Path $logPath -ChildPath $logFile
    return $logFilePath
}

function CheckAndInstallGit {
    Write-Log "Checking for Git installation"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git not found. Attempting installation via Chocolatey."
        if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Log "Installing Chocolatey..."
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            $chocoInstallScript = (Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing).Content
            Invoke-Expression $chocoInstallScript
        }
        choco install git -y --no-progress | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "Git installation failed."
        }
    }
    Write-Log "Git is installed. Version: $(git --version)"
}

# Main Script
$repoUrl = 'https://github.com/IT-Surgery/Scripts.git'
$global:logFilePath = Setup-Log "Logs\Git\" "Clone-Git-Repo"

CheckAndInstallGit

# Installing PowerShell Modules
$modules = 'PackageManagement', 'PendingReboot'
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Install-Module -Name $module -SkipPublisherCheck -Force
        Import-Module $module
        Write-Log "Installed and imported module $module."
    }
}

# Clone Repository
$drive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$urlParts = $repoUrl -split '/'
$repoOwner = $urlParts[-2]
$repoName = $urlParts[-1] -replace '\.git$', ''
$saveLocation = Join-Path -Path $drive -ChildPath "Git\$repoOwner\$repoName"

if (Test-Path $saveLocation) {
    Write-Log "Repository exists at $saveLocation. Deleting for a fresh clone."
    Remove-Item -Path $saveLocation -Recurse -Force
}

Write-Log "Cloning repository to $saveLocation"
git clone $repoUrl $saveLocation 2>&1 | Out-File -FilePath $global:logFilePath -Append -Encoding utf8
