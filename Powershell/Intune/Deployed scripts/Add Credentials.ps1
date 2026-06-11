#requires -version 5.1

$ErrorActionPreference = "Stop"

$TargetName = "server"
$Username   = "ad.tandartspraktijkelders.nl\homedir"
$Password   = "6EwSn8j0%4y@&u"

# Eventueel bestaande Generic credential verwijderen
cmdkey /delete:$TargetName 2>$null

# Windows Credential toevoegen
$process = Start-Process -FilePath "$env:SystemRoot\System32\cmdkey.exe" `
    -ArgumentList @(
        "/add:$TargetName",
        "/user:$Username",
        "/pass:$Password"
    ) `
    -NoNewWindow `
    -Wait `
    -PassThru

if ($process.ExitCode -ne 0) {
    throw "cmdkey is mislukt met exit code $($process.ExitCode)"
}

# Controle
$check = cmdkey /list

if ($check -match [regex]::Escape($TargetName)) {
    Write-Output "Windows credential toegevoegd voor $TargetName"
    exit 0
}

throw "Credential niet gevonden na toevoegen."