   <#
.SYNOPSIS
Import script voor (Vecozo) certificaten

.DESCRIPTION
Dit script importeert alle Vecozo certificaten vanuit een opgegeven locatie, en verwijdert eventuele verlopen certificaten uit de Personal Certificate Store van de gebruiker.
Stel dit script in als USER login script. Let op dat je het niet als Administrator of SYSTEM uitvoert, omdat vanuit die context de gebruikerscertificaten van de ingelogde gebruiker niet zichtbaar zijn.
Wijzig het import-wachtwoord van het certificaat en het pad waar de certificaten opgeslagen staan. Let op dat alle certificaten uit dit pad geimporteerd worden, dus ook persoonlijke Vecozo certificaten.
#>

# Het wachtwoord voor het importeren van de certificaten
$mypwd = ConvertTo-SecureString -String "1234" -Force -AsPlainText
# Pad naar de directory met de te importeren PFX-bestanden
$directoryPath = "\\srv-02\ClientApps$\Certificaten\Vecozo"

# Hieronder niets aanpassen

# Functie voor verwijderen van verlopen gebruikerscertificaten uit de Personal Certificate Store
function Remove-ExpiredCertificates {
    param (
        [string]$directoryPath
    )

    $certs = Get-ChildItem -Path Cert:\CurrentUser\My
    $currentDate = Get-Date
    $expiredCertsFound = $false

    foreach ($cert in $certs) {
        if ($cert.NotAfter -lt $currentDate) {
            Write-Host "Verlopen certificaat gevonden: $($cert.Subject)"
            Remove-Item $cert.PSPath
            Write-Host "Verlopen certificaat verwijderd."
            $expiredCertsFound = $true
        }
    }

    if (-not $expiredCertsFound) {
        Write-Host "Geen verlopen certificaten gevonden."
    }
}

try {
    # Controleer of de opgegeven directory bestaat
    if (Test-Path -Path $directoryPath -PathType Container) {
        # Haal alle PFX-bestanden op in de opgegeven directory en submappen
        $pfxFiles = Get-ChildItem -Path $directoryPath -Filter "*.pfx" -File -Recurse

        # Importeer elk PFX-bestand met het opgegeven wachtwoord
        foreach ($pfxFile in $pfxFiles) {
            Import-PfxCertificate -FilePath $pfxFile.FullName -Password $mypwd -CertStoreLocation Cert:\CurrentUser\My
        }
        Write-Host "Nieuwe certificaten geimporteerd"

        # Verwijder verlopen certificaten
        Write-Host "Verwijderen van verlopen certificaten..."
        Remove-ExpiredCertificates -directoryPath $directoryPath
        Write-Host "Verlopen certificaten verwijderd"
    }
    else {
        Write-Host "De opgegeven directory bestaat niet: $directoryPath"
    }
}
catch {
    Write-Host "Er is een fout opgetreden: $_"
}