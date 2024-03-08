<#
.SYNOPSIS
This script installs Chocolatey with Git, Notepad++, and PowerShell Core default packages.

.DESCRIPTION
The script performs the following actions:
- Installs Chocolatey.
- Installs Git and adds it to the system PATH.
- Installs Notepad++.
- Installs PowerShell Core.

.NOTES
Version:        1.4
Author:         Darren Pilkington
Creation Date:  04-03-2024
#>

Write-Output "Installing Chocolatey with Git, Notepad++, and PowerShell Core"

# Define a list of default packages to be installed
$chocoPackages = 'git', 'notepadplusplus', 'powershell-core'

Write-Output "Checking if Chocolatey is already installed. If not, install it."
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $chocoInstallScript = (Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing).Content
    if ($chocoInstallScript) {
        Invoke-Expression $chocoInstallScript
    } else {
        Write-Error "Failed to download Chocolatey installation script."
    }
}

# Install each package
foreach ($package in $chocoPackages) {
    try {
        if (!(choco list --local-only | Select-String -Pattern $package)) {
            choco install $package -y --no-progress
        }
    } catch {
        Write-Output "$package is already installed or encountered an error."
    }
}

# Specifically for Git, ensure it is added to PATH
$gitPath = 'C:\Program Files\Git\cmd'
if (!(Test-Path $gitPath)) {
    Write-Output "Git path not found, checking for installation..."
    # If Git was just installed and path is not found, attempt to locate it dynamically
    $gitInstallPath = Get-ChildItem -Path 'C:\Program Files\' -Filter Git -Recurse -Directory | Select-Object -ExpandProperty FullName | Where-Object { $_ -match 'Git\\cmd$' } | Select-Object -First 1
    if ($gitInstallPath) {
        $gitPath = $gitInstallPath
    }
}

if ($gitPath -and !(($env:Path -split ';') -contains $gitPath)) {
    Write-Output "Adding Git to system PATH..."
    $env:Path += ";$gitPath"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
}

# Refresh environment variables for the current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

Write-Output "Installation complete. Verifying Git installation..."
git --version

Write-Output "Please verify Git and other packages are correctly installed."
