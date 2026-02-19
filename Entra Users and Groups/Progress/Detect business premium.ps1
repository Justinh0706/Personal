<#
.SYNOPSIS
    Zoekt een specifieke Microsoft 365-groep ("License-BusinessPremium").
    Vraagt om een referentiegebruiker, toont diens licenties, en vraagt om de SkuId
    voor M365 Business Premium te selecteren. Deze SkuId wordt vervolgens gebruikt
    om de licentie toe te wijzen aan de doelgroep.

.DESCRIPTION
    Dit script is specifiek ontworpen om een Business Premium licentie toe te wijzen
    aan de groep "License-BusinessPremium", waarbij de exacte SkuId van de licentie
    interactief wordt bepaald via een gebruikersselectie. Dit is handig in tenants
    waar de SkuId voor Business Premium niet consistent automatisch kan worden gedetecteerd.

    Stappen:
    1. Maakt verbinding met Microsoft Graph.
    2. Zoekt de vooraf gedefinieerde doelgroep: "License-BusinessPremium".
    3. Gaat in een lus:
       - Vraagt om de UserPrincipalName (UPN) van een gebruiker die de 'M365 Business Premium' licentie heeft.
       - Valideert of deze gebruiker bestaat en actief is.
       - Toont alle toegewezen SkuId's van deze gebruiker.
       - Vraagt om de correcte SkuId voor 'M365 Business Premium' te kopiëren/bevestigen uit deze lijst.
       - Valideert of de ingevoerde SkuId daadwerkelijk bij de gebruiker hoort.
       - Bij ongeldige invoer, vraagt het script opnieuw om een gebruiker.
    4. Wijst de geselecteerde SkuId toe aan de groep "License-BusinessPremium".
#>
[CmdletBinding()]
param (
    # Geen parameters, de groepsnaam is statisch en de SkuId wordt interactief bepaald.
)

# --- Configuratie ---
$targetGroupName = "License-BusinessPremium" # De statische weergavenaam van de groep waaraan de licentie moet worden toegewezen
$businessPremiumLicenseDisplayName = "Microsoft 365 Business Premium" # Naam voor display, niet voor lookup

# --- Script Start ---

try {
    # Stap 1: Verbinding maken met Microsoft Graph
    Write-Host "Stap 1: Verbinding maken met Microsoft Graph..." -ForegroundColor Yellow
    # Scopes: Group.ReadWrite.All voor Set-MgGroupLicense, User.Read.All voor het ophalen van gebruikerslicenties
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"
    Write-Host "✓ Verbonden met Microsoft Graph." -ForegroundColor Green

    # Stap 2: Zoek de doelgroep
    Write-Host "`nStap 2: Zoeken naar de doelgroep '$targetGroupName'..." -ForegroundColor Yellow
    $targetGroup = Get-MgGroup -Filter "displayName eq '$targetGroupName'"
    
    if (-not $targetGroup) {
        throw "De groep met de naam '$targetGroupName' kon niet worden gevonden. Zorg dat deze bestaat."
    }
    if ($targetGroup.Count -gt 1) {
        throw "Meerdere groepen gevonden met de naam '$targetGroupName'. Zorg voor een unieke groepsnaam."
    }
    Write-Host "✓ Groep gevonden: $($targetGroup.DisplayName) (ID: $($targetGroup.Id))" -ForegroundColor Green

    # Stap 3: Bepaal de Business Premium SkuId via een referentiegebruiker (interactief)
    $businessPremiumSkuIdToUse = $null
    while ($null -eq $businessPremiumSkuIdToUse) {
        Write-Host "`nStap 3: '$businessPremiumLicenseDisplayName' SkuId bepalen voor licentietoewijzing." -ForegroundColor Yellow
        $referenceUserUpn = Read-Host "Geef de UPN (e-mailadres) op van EEN GEBRUIKER die al de '$businessPremiumLicenseDisplayName' licentie heeft"

        if ([string]::IsNullOrWhiteSpace($referenceUserUpn)) {
            Write-Warning "Invoer is leeg. Probeer het opnieuw."
            continue
        }

        try {
            # Haal assignedLicenses op om de SkuId's te kunnen tonen
            $refUser = Get-MgUser -UserId $referenceUserUpn -Property "id,displayName,assignedLicenses,accountEnabled" -ErrorAction Stop
        }
        catch {
            Write-Warning "Gebruiker '$referenceUserUpn' kon niet worden gevonden. Controleer het e-mailadres en probeer het opnieuw."
            continue
        }

        # Valideer 1: Account moet actief zijn
        if ($refUser.AccountEnabled -ne $true) {
            Write-Warning "✗ Gebruiker '$($refUser.DisplayName)' is niet actief (geblokkeerd). Kies een actieve gebruiker."
            continue
        }

        # Valideer 2: Gebruiker moet licenties hebben
        $allAssignedSkuIds = $null
        if ($null -ne $refUser.AssignedLicenses -and $refUser.AssignedLicenses.Count -gt 0) {
            $allAssignedSkuIds = $refUser.AssignedLicenses | Select-Object -ExpandProperty SkuId
            Write-Host "`nDe volgende SkuId's zijn toegewezen aan '$($refUser.DisplayName)':" -ForegroundColor Cyan
            $allAssignedSkuIds | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
        } else {
            Write-Warning "Gebruiker '$($refUser.DisplayName)' heeft geen direct toegewezen licenties. Kies een andere gebruiker."
            continue
        }
        
        # Vraag de gebruiker om de correcte SkuId te selecteren/bevestigen
        $selectedSkuId = Read-Host "`nKopieer en plak de exacte SkuId hierboven die overeenkomt met '$businessPremiumLicenseDisplayName'"
        
        # Valideer 3: De ingevoerde SkuId moet daadwerkelijk een van de toegewezen licenties zijn
        if ($allAssignedSkuIds -contains $selectedSkuId) {
            $businessPremiumSkuIdToUse = $selectedSkuId
            Write-Host "✓ SkuId '$businessPremiumSkuIdToUse' geselecteerd voor licentietoewijzing." -ForegroundColor Green
        } else {
            Write-Warning "De ingevoerde SkuId '$selectedSkuId' is NIET gevonden bij de opgegeven gebruiker '$($refUser.DisplayName)'. Probeer het opnieuw."
            # Blijft in de lus, vraagt opnieuw om een referentiegebruiker
        }
    }

    # Stap 4: Licentie toewijzen aan de groep
    Write-Host "`nStap 4: Licentie '$businessPremiumLicenseDisplayName' (SkuId: $businessPremiumSkuIdToUse) toewijzen aan groep '$targetGroupName'..." -ForegroundColor Yellow
    
    # Controleer eerst of de licentie al aan de groep is toegewezen
    $currentGroupSkus = (Get-MgGroup -GroupId $targetGroup.Id -Property "assignedLicenses").AssignedLicenses.SkuId

    if ($currentGroupSkus -contains $businessPremiumSkuIdToUse) {
        Write-Host "✓ Licentie '$businessPremiumLicenseDisplayName' is al toegewezen aan groep '$targetGroupName'." -ForegroundColor Cyan
    } else {
        Set-MgGroupLicense -GroupId $targetGroup.Id `
                           -AddLicenses @{ SkuId = $businessPremiumSkuIdToUse } `
                           -RemoveLicenses @() # Laat andere licenties ongemoeid
        Write-Host "✅ Licentie '$businessPremiumLicenseDisplayName' succesvol toegewezen aan groep '$targetGroupName'." -ForegroundColor Green
    }
}
catch {
    Write-Error "Er is een fout opgetreden: $($_.Exception.Message)"
}
finally {
    if (Get-MgContext) {
        Write-Host "`nVerbinding met Microsoft Graph wordt verbroken."
        Disconnect-MgGraph
    }
}