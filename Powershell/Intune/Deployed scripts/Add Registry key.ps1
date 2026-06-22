# Registry Key Configuration for Terminal Services Client Redirection Warning
# Purpose: Suppress the Terminal Services Redirection Warning Dialog
# Path: HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services\Client
# Key: RedirectionWarningDialogVersion (DWORD 32, Value: 1)

# Define registry path
$registryPath = "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client"
$registryKey = "RedirectionWarningDialogVersion"
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
