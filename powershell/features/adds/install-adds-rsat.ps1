<#
.SYNOPSIS
This script installs Active Directory Domain Services related RSAT tools.

.DESCRIPTION
The script installs the AD Domain Services Remote Server Administration Tools.

.NOTES
Version: 1.0
Author: IT Surgery
Modification Date: 08-03-2024

#>

# Determine the log file location based on the existence of D:\
$logPath = if (Test-Path D:\) { "D:\Logs\RSAT\" } else { "C:\Logs\RSAT\" }
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force
}
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "${logPath}Install-RSAT-$currentDateTime.log"

function Log-Message {
    Param (
        [string]$Message
    )
    Write-Output $Message
    $Message | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Log-Message "Installing Windows Server Roles & Features"
Import-Module ServerManager -Verbose:$false
Log-Message "Installing specified RSAT Features"

# Specify the desired features
$desiredFeatures = @(
    'GPMC',
    'RSAT-AD-Tools',
    'RSAT-ADCS',
    'RSAT-DNS-Server',
    'RSAT-File-Services',
    'RSAT-DFS-Mgmt-Con',
    'Telnet-Client'
)

# Flag to check if a reboot is required
$rebootRequired = $false

foreach ($FeatureName in $desiredFeatures) {
    $Feature = Get-WindowsFeature -Name $FeatureName
    if ($Feature.Installed -eq $False) {
        $installResult = Install-WindowsFeature -Name $FeatureName -IncludeManagementTools
        Log-Message "$FeatureName installed successfully."

        # Check if the installed feature requires a reboot
        if ($installResult.RestartNeeded -eq 'Yes') {
            $rebootRequired = $true
        }
    } else {
        Log-Message "$FeatureName is already installed."
    }
}

# Check the flag and reboot if required
if ($rebootRequired) {
    Log-Message "Rebooting the computer due to feature installation."
    Restart-Computer -Force
} else {
    Log-Message "No reboot required."
}

Log-Message "Import the PSReadLine module"
Import-Module -Name PSReadLine -Verbose:$false
