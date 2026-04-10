$RegPath = "HKCU:\Software\Policies\Microsoft\Edge"
$RegName = "BrowserSignin"
$RegValue = 1

Set-ExecutionPolicy Bypass -Scope CurorentUser -Frce

# Zorg dat het pad bestaat
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

# Zet of update de registry value
Set-ItemProperty `
    -Path $RegPath `
    -Name $RegName `
    -Value $RegValue `
    -PropertyType DWORD `
    -Force | Out-Null
