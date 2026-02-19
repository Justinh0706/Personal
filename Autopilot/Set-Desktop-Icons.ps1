# Wait
Start-Sleep -Seconds 2

# Controleer of de sleutel bestaat, zo niet, maak deze aan
$path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
if (-not (Test-Path $path)) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons" -Name "NewStartPanel" -Force
}

# Stel de waarde in
Set-ItemProperty -Path $path -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value "0" -Type DWord

# Wait
Start-Sleep -Seconds 2

Exit