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

# Get the FQDN of the domain the server is a member of
$fqdn = (Get-ADDomain).DNSRoot
$domainParts = $fqdn -split "\."
$DomainPrefix = $domainParts[0]
$DomainSuffix = $domainParts[1]

Write-Output "Creating OUs"
$ouName = "Domain Groups"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Application Groups"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Domain Groups,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Server Local Admins"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Domain Groups,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "AD-ActiveDirectory-Groups"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Application Groups,OU=Domain Groups,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Domain Servers"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "AD-ActiveDirectory-Servers"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Domain Servers,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Domain Users"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Privileged Users"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Domain Users,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Non-Privileged Users"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Domain Users,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "Service Accounts"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=Domain Users,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "IDM Groups"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "IDM Host Groups"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=IDM Groups,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}
$ouName = "IDM Server Local Admins"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path "OU=IDM Groups,DC=$DomainPrefix,DC=$DomainSuffix"
} else {Write-Output "OU $ouName already exists."}

Write-Output "Creating Block All GPOs OU and blocking GPO inheritance"
$ouName = "Block All GPOs"
$ouPath = "OU=Domain Servers,DC=$DomainPrefix,DC=$DomainSuffix"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    $ou = New-ADOrganizationalUnit -Name $ouName -Path $ouPath
    Write-Output "The $ouName OU has been created ..."
    $retryCount = 0
    $maxRetries = 60
    $retryInterval = 10 # seconds
    do {
        Start-Sleep -Seconds $retryInterval
        $ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
        $retryCount++
    } while ($null -eq $ou.DistinguishedName -and $retryCount -lt $maxRetries)
    if ($null -eq $ou.DistinguishedName) {
        Write-Output "Failed to retrieve the OU after $maxRetries attempts."
        return}
    Write-Output "Blocking GPO inheritance for $ouName ..."
    Set-GPInheritance -Target $ou.DistinguishedName -IsBlocked Yes} else {
    Write-Output "OU $ouName already exists."
    Write-Output "Checking if GPO inheritance is already blocked ..."
    $inheritance = Get-GPInheritance -Target $ou.DistinguishedName
    Write-Output "Blocked Inheritance Value Is $($inheritance.GpoInheritanceBlocked)"
    if ($inheritance.GpoInheritanceBlocked -ne "Yes") {
        Set-GPInheritance -Target $ou.DistinguishedName -IsBlocked Yes
        Write-Output "GPO inheritance blocked for $ouName."
    } else {Write-Output "GPO inheritance is already blocked for $ouName."}
}

Write-Output "Creating Default Computer Staging OU"
$ouName = "Staging"
$ouPath = "OU=Domain Servers,DC=$DomainPrefix,DC=$DomainSuffix"
$fullOuPath = "OU=$ouName,$ouPath"
$ou = Try {Get-ADOrganizationalUnit -Filter { Name -eq $ouName }} Catch {$null}
if ($null -eq $ou) {
    New-ADOrganizationalUnit -Name $ouName -Path $ouPath
    Write-Output "OU $ouName created."
} else {Write-Output "OU $ouName already exists."}
Write-Output "Redirecting default computer container to the Staging OU ..."
# Retrieve the current default location for new computer objects
$currentContainer = (Get-ADDomain).ComputersContainer
Write-Output "Current default computer container is $currentContainer."
# Check if the current container matches the desired container
if ($currentContainer -ne $fullOuPath) {
    redircmp $fullOuPath
    Write-Output "Default computer container redirected to $fullOuPath."
} else {Write-Output "Default computer container is already set to $fullOuPath."}
