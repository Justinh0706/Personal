# Force Windows Update Script for RMM Deployment
# This script installs the PSWindowsUpdate module if not present, checks for updates, and installs them.
# Exit codes:
# 0: Success (updates installed or no updates available)
# 1: Not running as administrator
# 2: Failed to install PSWindowsUpdate module
# 3: Failed to import PSWindowsUpdate module
# 4: Failed to get Windows updates
# 5: Failed to install updates

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: Script must be run as administrator."
    [Environment]::Exit(1)
}

# Install PSWindowsUpdate module if not present
try {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "Installing PSWindowsUpdate module..."
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
        Write-Host "PSWindowsUpdate module installed successfully."
    } else {
        Write-Host "PSWindowsUpdate module is already installed."
    }
} catch {
    Write-Host "Error: Failed to install PSWindowsUpdate module: $_"
    [Environment]::Exit(2)
}

# Import module
try {
    Import-Module PSWindowsUpdate
    Write-Host "PSWindowsUpdate module imported successfully."
} catch {
    Write-Host "Error: Failed to import PSWindowsUpdate module: $_"
    [Environment]::Exit(3)
}

# Get available updates
try {
    $updates = Get-WindowsUpdate
    if ($updates.Count -eq 0) {
        Write-Host "No updates available."
        [Environment]::Exit(0)
    } else {
        Write-Host "Found $($updates.Count) updates. Installing..."
    }
} catch {
    Write-Host "Error: Failed to get Windows updates: $_"
    [Environment]::Exit(4)
}

# Install updates (without auto-reboot to allow RMM to handle restart)
try {
    Install-WindowsUpdate -AcceptAll -AutoReboot:$false
    Write-Host "Updates installed successfully. A restart may be required."
    [Environment]::Exit(0)
} catch {
    Write-Host "Error: Failed to install updates: $_"
    [Environment]::Exit(5)
}
