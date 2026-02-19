# Test connection to Azure storage account
$connectTestResult = Test-NetConnection -ComputerName viedentastorage001.file.core.windows.net -Port 445

if (-not $connectTestResult.TcpTestSucceeded) {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
    exit 1
}

# Connection successful, proceed with drive management
Write-Host "Connection to Azure storage account successful."

# Check if drive Z already exists and remove it
if (Get-PSDrive -Name T -ErrorAction SilentlyContinue) {
    Write-Host "Drive T already exists. Removing it..."
    Remove-PSDrive -Name T -Force
    Write-Host "Drive T removed successfully."
}

# Remove existing cmdkey entry if it exists
Write-Host "Removing existing cmdkey entry..."
cmd.exe /C "cmdkey /delete:`"viedentastorage001.file.core.windows.net`""

# Save the password so the drive will persist on reboot
cmd.exe /C "cmdkey /add:`"viedentastorage001.file.core.windows.net`" /user:`"localhost\viedentastorage001`" /pass:`"Passkeytoevoegen`""

# Mount the drive
try {
    New-PSDrive -Name T -PSProvider FileSystem -Root "\\viedentastorage001.file.core.windows.net\import-export" -Persist
    Write-Host "Drive T mounted successfully."
} catch {
    Write-Error -Message "Failed to mount drive T: $_"
    exit 1
}