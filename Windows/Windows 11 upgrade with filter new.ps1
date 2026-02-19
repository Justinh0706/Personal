<# 
    Windows 11 Silent Upgrade Script
    - Hostname filter
    - Automatische ISO-download vanaf Microsoft
    - Automatisch uitpakken naar C:\Install\Win11
    - Silent upgrade naar Windows 11
    - Ontworpen voor gebruik via RMM (geen rode fouten)
#>

$ErrorActionPreference = "Stop"

function Download-Win11ISO {
    param(
        [string]$Destination = "C:\Install\Win11\Win11.iso"
    )

    Write-Host "Windows 11 ISO wordt gedownload vanaf Microsoft..."

    # Zorg dat TLS 1.2 gebruikt wordt (oudere PowerShell heeft dit soms nodig)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Host "Kon TLS-protocol niet forceren, ga verder met standaard instellingen..."
    }

    # Voorbeeld: Nederlandse Windows 11 23H2 x64 ISO
    $url = "https://software-download.microsoft.com/db/Win11_23H2_Dutch_x64.iso"

    Invoke-WebRequest -Uri $url -OutFile $Destination -UseBasicParsing

    Write-Host "ISO gedownload naar: $Destination"
    return $Destination
}

function Extract-Win11ISO {
    param(
        [string]$ISOPath,
        [string]$TargetFolder = "C:\Install\Win11"
    )

    Write-Host "ISO wordt gemount..."

    $mount = Mount-DiskImage -ImagePath $ISOPath -PassThru
    $volume = $mount | Get-Volume
    $driveLetter = $volume.DriveLetter

    if (-not $driveLetter) {
        Write-Host "Kon geen driveletter bepalen voor de gemounte ISO. Stop."
        return
    }

    Write-Host "ISO gemount als drive ${driveLetter}:"

    $source = "${driveLetter}:\"
    Write-Host "Installatiebestanden worden gekopieerd van ${source} naar $TargetFolder ..."

    Copy-Item -Path ($source + "*") -Destination $TargetFolder -Recurse -Force

    Write-Host "ISO wordt ontkoppeld..."
    Dismount-DiskImage -ImagePath $ISOPath
}

try {
    Write-Host "=== Windows 11 Silent Upgrade Script gestart ==="

    # === Hostname Filter ===
    $TargetHosts = @(
        "SID-104111",
        "SID-103798"
        "SID-105964"
    )

    $currentHost = $env:COMPUTERNAME

    if (-not ($TargetHosts -contains $currentHost)) {
        Write-Host "Host '$currentHost' staat niet in de targetlijst. Geen actie nodig."
        exit 0
    }

    Write-Host "Host '$currentHost' staat in de targetlijst. Ga door..."

    # === OS-check: draait de machine al Windows 11? ===
    $os = Get-CimInstance Win32_OperatingSystem
    $osCaption = $os.Caption
    $osVersion = [version]$os.Version

    Write-Host "Huidig OS: $osCaption ($osVersion)"

    if ($osCaption -like "*Windows 11*" -or $osVersion -ge [version]"10.0.22000.0") {
        Write-Host "Deze machine draait al Windows 11. Geen upgrade nodig."
        exit 0
    }

    Write-Host "Machine draait nog geen Windows 11. Upgrade wordt voorbereid..."

    # === Installatiepad ===
    $SetupFolder = "C:\Install\Win11"

    if (-not (Test-Path $SetupFolder)) {
        Write-Host "Installatiemap '$SetupFolder' bestaat niet. Map wordt aangemaakt..."
        New-Item -ItemType Directory -Path $SetupFolder | Out-Null
    }

    $SetupExe = Join-Path $SetupFolder "setup.exe"

    # === Automatische ISO download & extract indien setup.exe ontbreekt ===
    if (-not (Test-Path $SetupExe)) {
        Write-Host "setup.exe niet gevonden in '$SetupFolder'. Windows 11 ISO wordt automatisch opgehaald..."

        $isoPath = Join-Path $SetupFolder "Win11.iso"

        if (-not (Test-Path $isoPath)) {
            Download-Win11ISO -Destination $isoPath
        } else {
            Write-Host "Win11.iso bestaat al op $isoPath, gebruik bestaande ISO."
        }

        Extract-Win11ISO -ISOPath $isoPath -TargetFolder $SetupFolder

        if (-not (Test-Path $SetupExe)) {
            Write-Host "WAARSCHUWING: setup.exe nog steeds niet gevonden in '$SetupFolder'."
            Write-Host "Stop zonder fout (RMM blijft groen)."
            exit 0
        }
    }

    Write-Host "setup.exe gevonden op: $SetupExe"
    Write-Host "Windows 11 upgrade wordt gestart in silent mode..."

    # === Windows Setup silent upgrade ===
    # /auto upgrade   = automatische upgrade
    # /quiet          = geen UI
    # /noreboot       = reboot later door RMM / beheerder
    # /dynamicupdate  = actuele setup-updates ophalen
    $arguments = "/auto upgrade /quiet /noreboot /dynamicupdate enable"

    $process = Start-Process -FilePath $SetupExe -ArgumentList $arguments -Wait -PassThru

    $exitCode = $process.ExitCode
    Write-Host "setup.exe afgerond met exitcode: $exitCode"

    switch ($exitCode) {
        0 {
            Write-Host "Windows 11 upgrade is succesvol gestart/afgerond. Reboot via RMM plannen."
            exit 0
        }
        3010 {
            Write-Host "Windows 11 upgrade afgerond, reboot vereist. Geen fout, alleen reboot nodig."
            exit 0
        }
        default {
            Write-Host "Fout tijdens Windows 11 installatie: exitcode $exitCode"
            # Bewust nog steeds 0, zodat RMM niet rood wordt:
            exit 0
        }
    }
}
catch {
    Write-Host "WAARSCHUWING: er is een fout opgetreden in het script: $($_.Exception.Message)"
    # Geen 'error' richting RMM:
    exit 0
}
