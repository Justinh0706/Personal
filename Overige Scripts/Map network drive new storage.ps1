$connectTestResult = Test-NetConnection -ComputerName storagesupra.file.core.windows.net -Port 445
if ($connectTestResult.TcpTestSucceeded) {
    # Save the password so the drive will persist on reboot
    cmd.exe /C "cmdkey /add:`"storagesupra.file.core.windows.net`" /user:`"localhost\storagesupra`" /pass:`"JYFosSZBYNHPDJedl6dqUQjRNZF14xBE8EaIIV3EumtKsdPbmNCZCUmbC95iiMqpk8FX1RXTULiJ+AStXorTsw==`""
    # Mount the drive
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\storagesupra.file.core.windows.net\test" -Persist
} else {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
}