<#
.SYNOPSIS
Efficient script to ensure a fresh copy of a specified Git repository is downloaded.

.DESCRIPTION
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
if (-not [string]::IsNullOrWhiteSpace($stdout)) {WriteLog "Output: $stdout" $LogFilePath}
if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    # Treat STDERR as warning unless the process exited with a non-zero code which indicates an error
    if ($process.ExitCode -ne 0) {WriteLog "Error: $stderr" $LogFilePath} else {WriteLog "Warning: $stderr" $LogFilePath}
}
if ($process.ExitCode -ne 0) {WriteLog "Failed to clone the repository. See the error message above." $LogFilePath
} else {WriteLog "Repository cloned successfully to $saveLocation." $LogFilePath}
