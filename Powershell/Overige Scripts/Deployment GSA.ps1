# URL to download: https://aka.ms/DownloadGSAWindowsClient
$installerName = "GlobalSecureAccessClient.exe"
$logFile = "$env:ProgramData\GSAInstall.log"

# Run installation
Start-Process -FilePath ".\$installerName" -ArgumentList "/quiet /norestart" -Wait -NoNewWindow -PassThru

# Check for success
if ($LASTEXITCODE -eq 0) {
    Write-Output "Global Secure Access Client installed successfully."
} else {
    Write-Output "Installation failed with exit code $LASTEXITCODE."
}
