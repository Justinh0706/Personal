#Requires -RunAsAdministrator

# Stop NVIDIA Display Container LS Service and set to Manual startup

$ServiceName = "NVDisplay.ContainerLocalSystem"

# Check if service exists
$Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $Service) {
    Write-Host "Service '$ServiceName' niet gevonden." -ForegroundColor Red
    exit 1
}

# Stop the service if running
if ($Service.Status -eq "Running") {
    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
}

# Set startup type to Manual
try {
    Set-Service -Name $ServiceName -StartupType Manual -ErrorAction Stop
}
catch {
    Write-Host "Error: Kon startup type niet instellen op Manual." -ForegroundColor Red
    exit 1
}

Write-Host "Success: de NVIDIA Display Container LS service is gestopt en op handmatig uitvoeren gezet." -ForegroundColor Green
exit 0
