# Script om oude bestanden in een specifieke map te verwijderen

# --- Instellingen ---
# De naam van de map waarnaar gezocht moet worden.
$mapNaam = "Xrayimages"

# Het startpunt voor de zoekopdracht.
$zoekPad = "C:\"

# De ouderdom van de bestanden die verwijderd moeten worden (in dagen).
$dagenOud = -547

# --- Scriptlogica ---

# Zoek naar de map op het opgegeven pad.
Write-Host "Zoeken naar de map '$mapNaam' op station '$zoekPad'..."
$doelMap = Get-ChildItem -Path $zoekPad -Filter $mapNaam -Recurse -Directory -ErrorAction SilentlyContinue | Select-Object -First 1

# Controleer of de map is gevonden.
if ($doelMap) {
    $mapPad = $doelMap.FullName
    Write-Host "Map gevonden op: $mapPad"

    # Bepaal de datumgrens voor het verwijderen van bestanden.
    $datumGrens = (Get-Date).AddDays($dagenOud)
    Write-Host "Bestanden ouder dan $datumGrens worden verwijderd."

    # Zoek naar bestanden in de doelmap die ouder zijn dan de ingestelde datumgrens.
    $teVerwijderenBestanden = Get-ChildItem -Path $mapPad -Recurse -File | Where-Object { $_.LastWriteTime -lt $datumGrens }

    # Controleer of er bestanden zijn om te verwijderen.
    if ($teVerwijderenBestanden) {
        Write-Host "De volgende bestanden worden verwijderd:"
        # Geef een lijst van de te verwijderen bestanden weer.
        $teVerwijderenBestanden | ForEach-Object {
            Write-Host "- $($_.FullName)"
        }

        # Verwijder de gevonden bestanden.
      
        $teVerwijderenBestanden | Remove-Item -Force 

        Write-Host "Operatie voltooid. Om de bestanden echt te verwijderen, verwijder de '-WhatIf' parameter in het script en voer het opnieuw uit."
    } else {
        Write-Host "Geen bestanden gevonden in '$mapPad' die ouder zijn dan 1,5 jaar."
    }
} else {
    Write-Host "De map '$mapNaam' is niet gevonden op station '$zoekPad'."
}