# Registry Key Configuration for Auto-Accept SSO Permissions
# Purpose: Automatically accept Single Sign-On permissions
# Path: HKLM\SOFTWARE\Policies\Microsoft\Windows\AAD
# Key: AutoAcceptSsoPermission (DWORD 32, Value: 1)

# Define registry path
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD"
$registryKey = "AutoAcceptSsoPermission"
$registryValue = 1
$registryType = "DWORD"

# Create registry path if it doesn't exist
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "Registry path created: $registryPath"
}

# Create or update the registry key
New-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -PropertyType $registryType -Force | Out-Null

# Verify the registry key was created
$prop = Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue
if ($prop -ne $null) {
    $value = $prop | Select-Object -ExpandProperty $registryKey
    Write-Host "Registry key successfully created/updated:"
    Write-Host "Path: $registryPath"
    Write-Host "Key: $registryKey"
    Write-Host "Value: $value"
    Write-Host "Type: $registryType"
} else {
    Write-Host "Error: Registry key could not be created." -ForegroundColor Red
    exit 1
}

Write-Host "Operation completed successfully." -ForegroundColor Green
