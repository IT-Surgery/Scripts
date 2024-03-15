<#
.SYNOPSIS
This script installs Active Directory Domain Services and creates a new Active Directory Forest.

.DESCRIPTION
The script installs the AD Domain Services role, configures DNS settings, sets up the PDC as an authoritative time server, and performs additional configurations for a new AD forest. It includes enabling the AD Recycle Bin, renaming the default site, and associating a subnet with the new site based on the server's TCP/IP settings.

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
.\[ScriptName].ps1 -AdDomainName "example.com" -AdNetbiosName "EXAMPLE" -Password "YourComplexPassword!"
#>

# Variables
$NewSiteName = "ADDS-Site-1"

# Dynamically determine subnet IP and mask for new site based on server's primary IPv4 address
$ipconfig = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp, Manual | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1
$subnetMaskLength = $ipconfig.PrefixLength
$ipAddress = $ipconfig.IPAddress
# Simplify subnet calculation to ensure correctness
function ConvertTo-Binary {
    param (
        [int]$decimal
    )
    $binary = [convert]::ToString($decimal, 2)
    return $binary.PadLeft(8, '0')
}
$ipBinary = ($ipAddress -split "\." | ForEach-Object { ConvertTo-Binary -decimal $_ }) -join ""
$subnetBinary = $ipBinary.Substring(0, $subnetMaskLength).PadRight(32, '0')
$subnetAddressBytes = @()
for ($i = 0; $i -lt 32; $i += 8) {
    $byte = $subnetBinary.Substring($i, 8)
    $subnetAddressBytes += [convert]::ToInt32($byte, 2)
}
$subnetAddress = $subnetAddressBytes -join "."
$NewSiteSubnet = "$subnetAddress/$subnetMaskLength"
Write-Output "Detected Subnet for New Site: $NewSiteSubnet"

Write-Output "Creating Baseline AD Objects"
Import-Module ActiveDirectory

Write-Output "Enabling AD Recycle Bin"
function IsADRecycleBinEnabled {
    $adForest = Get-ADForest
    Write-Output "Recycle Bin Enabled status: $($adForest.RecycleBinEnabled)"
    return $adForest.RecycleBinEnabled
}

# Directly use the function in the if-statement to check its return value
if (IsADRecycleBinEnabled -eq $true) {
    Write-Output "AD Recycle Bin is already enabled."
} else {
    try {
        # Enable the AD Recycle Bin without confirmation prompt
        Enable-ADOptionalFeature 'Recycle Bin Feature' `
            -Scope ForestOrConfigurationSet `
            -Target (Get-ADForest).Name `
            -Confirm:$false
        Write-Output "AD Recycle Bin has been successfully enabled."
    } catch {
        Write-Output "An attempt was made to enable AD Recycle Bin, but it failed with the following error: $_"
    }
}

Write-Output "Renaming Default-First-Site-Name to $NewSiteName"
# Check and rename the site if necessary
$oldSiteName = "Default-First-Site-Name"
try {
    $site = Get-ADReplicationSite -Identity $oldSiteName -ErrorAction Stop
    Rename-ADObject -Identity $site.DistinguishedName -NewName $NewSiteName
    Write-Output "Site name changed from $oldSiteName to $NewSiteName"
} catch {
    Write-Output "Site $oldSiteName has already been renamed or does not exist."
}

# Define and associate the subnets with the site
try {
    Get-ADReplicationSubnet -Identity $NewSiteSubnet -ErrorAction Stop
    Write-Output "Subnet $NewSiteSubnet already exists."
} catch {
    New-ADReplicationSubnet -Name $NewSiteSubnet -Site $NewSiteName -Location "$NewSiteName"
    Write-Output "Subnet $NewSiteSubnet associated with site $NewSiteName"
}
