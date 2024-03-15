<#
.SYNOPSIS
This script installs Active Directory Domain Services and creates a new Active Directory Forest.

.DESCRIPTION
The script installs the AD Domain Services role, configures DNS settings, sets up the PDC as an authoritative time server, and performs additional configurations for a new AD forest.

.NOTES
Version: 1.0
Author: IT Surgery
Modification Date: 08-03-2024

.PARAMETER AdDomainName
The desired Active Directory domain name. Default is "adds.private".

.PARAMETER AdNetbiosName
The NetBIOS name of the domain. Default is "ADDS".

.PARAMETER Password
The password for the Administrator account. Default is a pre-set complex password.

.EXAMPLE
.\ScriptName.ps1 -AdDomainName "example.com" -AdNetbiosName "EXAMPLE" -Password "YourComplexPassword!"
#>

param(
    [string]$AdDomainName = "adds.private",
    [string]$AdNetbiosName = "ADDS",
    [string]$Password = "C4ang3M3as@p01!"
)

# Convert the plain text password to a secure string
$Credential = ConvertTo-SecureString $Password -AsPlainText -Force

# Determine the installation drive based on availability
$AdDisk = if (Test-Path 'D:\') { "D:\" } else { "C:\" }
$AdDbPath = "${AdDisk}ADDS\Database"
$AdLogPath = "${AdDisk}ADDS\Log"
$AdSysvolPath = "${AdDisk}ADDS\SYSVOL"

Write-Output "Deploying an Active Directory Forest for $AdDomainName on $AdDisk drive."

$adRole = Get-WindowsFeature -Name 'AD-Domain-Services'

# Check if AD is not installed
if ($adRole.InstallState -ne 'Installed') {
    Write-Output "Installing Active Directory Domain Services (ADDS)"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Import-Module ADDSDeployment

    Install-ADDSForest `
        -CreateDnsDelegation:$false `
        -DatabasePath $AdDbPath `
        -DomainMode "Win2016" `
        -DomainName $AdDomainName `
        -DomainNetbiosName $AdNetbiosName `
        -ForestMode "Win2016" `
        -InstallDns:$true `
        -LogPath $AdLogPath `
        -NoRebootOnCompletion:$false `
        -SysvolPath $AdSysvolPath `
        -Force:$true `
        -SafeModeAdministratorPassword $Credential
} else {
    Write-Output "Active Directory has already been deployed."
}

# Setting DNS suffix for all active network connections
Write-Output "Setting the DNS suffix for all active network connections to $AdDomainName"
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
foreach ($adapter in $activeAdapters) {
    Set-DnsClient -InterfaceIndex $adapter.ifIndex -ConnectionSpecificSuffix $AdDomainName
    Write-Output "Set DNS suffix for $($adapter.Name) to $AdDomainName."
}

# Configuring the PDC as an authoritative time server
$ntpKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
$ntpServersValue = "time.windows.com,0x9" # Modify as necessary
$configKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config"
$announceFlagsValue = 5 # PDC should be set to 5 to act as a reliable time source

Write-Output "Configuring the PDC as an authoritative time server"
Set-ItemProperty -Path $ntpKeyPath -Name "NtpServer" -Value $ntpServersValue
Set-ItemProperty -Path $configKeyPath -Name "AnnounceFlags" -Value $announceFlagsValue
Set-Service -Name w32time -StartupType Automatic
Start-Service w32time

Write-Output "Active Directory Domain Services setup has completed. Please verify the installation and configuration."
