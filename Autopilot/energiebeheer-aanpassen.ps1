<#
.SYNOPSIS
    Stelt de time-outs voor het uitschakelen van het scherm en de slaapstand in op 'Nooit'.

.DESCRIPTION
    Dit script controleert of het met administratorrechten wordt uitgevoerd.
    Vervolgens gebruikt het de tool 'powercfg.exe' om de volgende instellingen
    voor het actieve energiebeheerschema aan te passen:
    - Scherm uitschakelen na (op netstroom): Nooit
    - Scherm uitschakelen na (op batterij): Nooit
    - Computer in slaapstand na (op netstroom): Nooit
    - Computer in slaapstand na (op batterij): Nooit

    Een waarde van '0' minuten staat voor 'Nooit'.
#>

# Stap 1: Controleer of het script als administrator wordt uitgevoerd
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Dit script moet worden uitgevoerd met administratorrechten."
    Write-Warning "Klik met de rechtermuisknop op het script en kies 'Als administrator uitvoeren'."
    # Wacht op een toetsaanslag voordat het venster sluit
    Read-Host "Druk op Enter om af te sluiten"
    exit
}

Write-Host "Bezig met aanpassen van energiebeheerinstellingen..." -ForegroundColor Cyan

try {
    # Stap 2: Stel de time-out voor het uitschakelen van het beeldscherm in op 'Nooit' (0 minuten)
    # -monitor-timeout-ac: op netstroom
    powercfg.exe -x -monitor-timeout-ac 0
    Write-Host "✅ Scherm time-out (netstroom) ingesteld op 'Nooit'." -ForegroundColor Green

    # -monitor-timeout-dc: op batterij
    powercfg.exe -x -monitor-timeout-dc 0
    Write-Host "✅ Scherm time-out (batterij) ingesteld op 'Nooit'." -ForegroundColor Green

    # Stap 3: Stel de time-out voor de slaapstand in op 'Nooit' (0 minuten)
    # -standby-timeout-ac: op netstroom
    powercfg.exe -x -standby-timeout-ac 0
    Write-Host "✅ Slaapstand time-out (netstroom) ingesteld op 'Nooit'." -ForegroundColor Green

    # -standby-timeout-dc: op batterij
    powercfg.exe -x -standby-timeout-dc 0
    Write-Host "✅ Slaapstand time-out (batterij) ingesteld op 'Nooit'." -ForegroundColor Green

    Write-Host "`nAlle instellingen zijn succesvol aangepast." -ForegroundColor Yellow
}
catch {
    Write-Error "Er is een fout opgetreden bij het aanpassen van de instellingen: $_"
}

# Wacht op een toetsaanslag voordat het venster sluit
Read-Host "Druk op Enter om af te sluiten"