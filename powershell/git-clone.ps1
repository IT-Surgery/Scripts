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

function CheckAndInstallGit {
    $LogFilePath = SetupLog "Logs\Git\" "Install-Git"
    WriteLog "Checking for Git installation" $LogFilePath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        WriteLog "Git not found. Attempting installation via Chocolatey." $LogFilePath
        InstallChocolatey $LogFilePath
        RefreshPath
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "Git installation failed."
        }
    }
    WriteLog "Git is installed. Version: $(git --version)" $LogFilePath
}

function InstallChocolatey {
    Param ([string]$LogFilePath)
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        WriteLog "Installing Chocolatey..." $LogFilePath
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $ChocoInstallScript = (Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing).Content
        Invoke-Expression $ChocoInstallScript
        WriteLog "Chocolatey installed successfully." $LogFilePath
    }
    if (!(choco list --local-only | Select-String -Pattern "git")) {
        choco install git -y --no-progress | Out-Null
        WriteLog "Git package installed via Chocolatey." $LogFilePath
    }
}

function RefreshPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function InstallPowerShellModules {
    Install-PackageProvider -Name NuGet -Force
    $LogFilePath = SetupLog "Logs\PowerShell\" "PowerShell-Modules-Install"
    $Modules = 'PackageManagement', 'PendingReboot'
    foreach ($Module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            Install-Module -Name $Module -SkipPublisherCheck -Force
            Import-Module $Module
            WriteLog "Installed and imported module $Module." $LogFilePath
        }
    }
}

# Main Script
$repoUrl = 'https://github.com/IT-Surgery/Scripts.git'

CheckAndInstallGit
InstallPowerShellModules

# Clone Repository
$LogFilePath = SetupLog "Logs\Git\" "Git-Clone"
$Drive = if (Test-Path D:\) { "D:\" } else { "C:\" }
$urlParts = $repoUrl -split '/'
$repoOwner = $urlParts[-2]
$repoName = $urlParts[-1] -replace '\.git$', ''
$saveLocation = Join-Path -Path $Drive -ChildPath "Git\$repoOwner\$repoName"

if (Test-Path $saveLocation) {
    WriteLog "Repository exists at $saveLocation. Deleting for a fresh clone." $LogFilePath
    Remove-Item -Path $saveLocation -Recurse -Force
}

WriteLog "Cloning repository to $saveLocation" $LogFilePath
$gitCommand = "git clone '$repoUrl' '$saveLocation'"
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = "powershell.exe"
$processInfo.RedirectStandardError = $true
$processInfo.RedirectStandardOutput = $true
$processInfo.UseShellExecute = $false
$processInfo.Arguments = "-Command $gitCommand"
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo
$process.Start() | Out-Null
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

# Log STDOUT and STDERR
if (-not [string]::IsNullOrWhiteSpace($stdout)) {Write-Log "Output: $stdout"}
if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    # Treat STDERR as warning unless the process exited with a non-zero code which indicates an error
    if ($process.ExitCode -ne 0) {Write-Log "Error: $stderr"} else {Write-Log "Warning: $stderr"}
}
if ($process.ExitCode -ne 0) {Write-Log "Failed to clone the repository. See the error message above."
} else {Write-Log "Repository cloned successfully to $saveLocation."}
