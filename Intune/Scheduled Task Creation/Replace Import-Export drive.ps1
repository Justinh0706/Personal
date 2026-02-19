$connectTestResult = Test-NetConnection -ComputerName viedentastorage001.file.core.windows.net -Port 445
if ($connectTestResult.TcpTestSucceeded) {
    # Save the password so the drive will persist on reboot
    cmd.exe /C "cmdkey /add:`"viedentastorage001.file.core.windows.net`" /user:`"localhost\viedentastorage001`" /pass:`"Passkeytoevoegen!`""
    # Mount the drive
    New-PSDrive -Name T -PSProvider FileSystem -Root "\\viedentastorage001.file.core.windows.net\import-export" -Persist
} else {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
}