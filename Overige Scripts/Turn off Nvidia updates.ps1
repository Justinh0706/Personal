# Script to disable NVIDIA driver updates through Windows Update
# With registry key existence check

$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$RegistryName = "ExcludeWUDriversInQualityUpdate"
$RegistryValue = 1

try {
    # Check if the registry key exists
    if (Test-Path -Path $RegistryPath) {
        # Check if the specific value already exists
        $KeyValue = Get-ItemProperty -Path $RegistryPath -Name $RegistryName -ErrorAction SilentlyContinue
        
        if ($null -ne $KeyValue.$RegistryName) {
            Write-Host "Registry key already exists: $RegistryPath\$RegistryName = $($KeyValue.$RegistryName)" -ForegroundColor Yellow
            exit 0  # Key already exists, exit successfully
        }
    }
    
    # If we reach here, the key doesn't exist, so add it
    New-ItemProperty -Path $RegistryPath -Name $RegistryName -Value $RegistryValue -PropertyType DWORD -Force | Out-Null
    Write-Host "Successfully added registry key" -ForegroundColor Green
    exit 0  # Successfully added, exit with success code
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1  # Exit with error code
}