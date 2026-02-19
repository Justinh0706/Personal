if (-not $siteValidated) {
        throw "De SharePoint site voor groep '$algemeenGroupName' met de gewenste URL is niet geprovisioneerd binnen de verwachte tijd. Script afgebroken."
    }
    Write-Host "SharePoint URL '$fullDesiredSharePointSiteUrl_Algemeen' is nu beschikbaar." -ForegroundColor Green

    Start-Sleep 10 # Kleine pauze voordat we verdergaan met de eigenaar toevoegen

    ##### Hier word een owner toegevoegd aan de algemeen groep zodat Teams geactiveerd kan worden. ####
    $businessPremiumLicenseDisplayName_Owner = "Microsoft 365 Business Premium" # Naam voor display
    $groupNameToSearch_Owner = "Algemeen" # De statische weergavenaam van de groep

    # Haal de groep opnieuw op, voor zekerheid, na eventuele heraanmaak
    $algemeenGroupForOwner = Get-MgGroup -Filter "displayName eq '$groupNameToSearch_Owner'" | Select-Object -First 1

    if (-not $algemeenGroupForOwner) {
        throw "Groep '$groupNameToSearch_Owner' is na aanmaak/validatie niet meer gevonden. Kan geen eigenaar toevoegen."
    }

    # Stap A (Owner): Vraag om de groepseigenaar en valideer deze in een lus
    $validOwner = $null
    $businessPremiumSkuIdToUse_Owner = $null # Deze variabele zal de SkuId voor de owner check bevatten

    while ($null -eq $validOwner) {
        Write-Host "`Stap A: Groepseigenaar selecteren en licentie valideren voor groep '$groupNameToSearch_Owner'." -ForegroundColor Yellow
        $ownerUserPrincipalName = Read-Host "Geef de UPN (e-mailadres) op van de GEBRUIKER die EIGENAAR moet worden van de groep"

        if ([string]::IsNullOrWhiteSpace($ownerUserPrincipalName)) {
            Write-Warning "Invoer is leeg. Probeer het opnieuw."
            continue
        }

        try {
            $potentialOwner = Get-MgUser -UserId $ownerUserPrincipalName -Property "id,displayName,assignedLicenses,accountEnabled" -ErrorAction Stop
        }
        catch {
            Write-Warning "Gebruiker '$ownerUserPrincipalName' kon niet worden gevonden. Controleer het e-mailadres en probeer het opnieuw."
            continue
        }

        # Validatie 1: Account moet actief zijn
        if ($potentialOwner.AccountEnabled -ne $true) {
            Write-Warning "Gebruiker '$($potentialOwner.DisplayName)' is niet actief (geblokkeerd). Kies een actieve gebruiker."
            continue
        }

        # Validatie 2: Toon de licenties en vraag om de juiste SkuId te selecteren
        $assignedSkuIds_Owner = $null
        if ($null -ne $potentialOwner.AssignedLicenses -and $potentialOwner.AssignedLicenses.Count -gt 0) {
            $assignedSkuIds_Owner = $potentialOwner.AssignedLicenses | Select-Object -ExpandProperty SkuId
            Write-Host "`nDe volgende SkuId's zijn toegewezen aan '$($potentialOwner.DisplayName)':" -ForegroundColor Cyan
            $assignedSkuIds_Owner | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
        } else {
            Write-Warning "Gebruiker '$($potentialOwner.DisplayName)' heeft geen direct toegewezen licenties. Kies een andere gebruiker."
            continue
        }
        
        $selectedSkuId_Owner = Read-Host "`nKopieer en plak de exacte SkuId hierboven die overeenkomt met '$businessPremiumLicenseDisplayName_Owner'"
        
        if ($assignedSkuIds_Owner -contains $selectedSkuId_Owner) {
            $businessPremiumSkuIdToUse_Owner = $selectedSkuId_Owner 
            Write-Host "De licentie (SkuId: $selectedSkuId_Owner) is geselecteerd voor controle." -ForegroundColor Green
            $validOwner = $potentialOwner # Gebruiker en SkuId zijn nu gevalideerd
        } else {
            Write-Warning "De ingevoerde SkuId '$selectedSkuId_Owner' is NIET gevonden bij de opgegeven gebruiker '$($potentialOwner.DisplayName)'. Probeer het opnieuw."
        }
    }

    # Stap B (Owner): Controleer of de gebruiker al eigenaar is en voeg toe indien nodig
    Write-Host "`nStap B: Controleren en toevoegen van eigenaar..." -ForegroundColor Yellow
    $currentOwners = Get-MgGroupOwner -GroupId $algemeenGroupForOwner.Id
    
    if ($validOwner.Id -in $currentOwners.Id) {
        Write-Host "$($validOwner.DisplayName) is al eigenaar van de groep '$($algemeenGroupForOwner.DisplayName)'." -ForegroundColor Cyan
        Write-Host "Script is voltooid, geen wijzigingen nodig."
    }
    else {
        New-MgGroupOwner -GroupId $algemeenGroupForOwner.Id -DirectoryObjectId $validOwner.Id
        Write-Host "SUCCES! '$($validOwner.DisplayName)' is nu eigenaar van de groep '$($algemeenGroupForOwner.DisplayName)'." -ForegroundColor Green
        Write-Host "De groep is nu klaar om er een Microsoft Team van te maken."
    }

    Start-sleep 10

    ####Teams Activeren####
    $teamsGroup = Get-MgGroup -Filter "displayName eq '$algemeenGroupName'" | Select-Object -First 1

    if ($teamsGroup) {
        try {
            # Teams activeren op de bestaande Microsoft 365 groep
            New-MgGroupTeam -GroupId $teamsGroup.Id `
                -MemberSettings @{ AllowCreateUpdateChannels = $true } `
                -MessagingSettings @{ AllowUserEditMessages = $true } `
                -ErrorAction Stop # Stop bij fouten bij het aanmaken van Teams

            Write-Host "Teams succesvol geactiveerd voor groep '$($teamsGroup.DisplayName)'" -ForegroundColor Green
        } catch {
            Write-Warning "Fout bij activeren van Teams op groep '$($teamsGroup.DisplayName)': $($_.Exception.Message)"
            Write-Warning "Controleer of de groep voldoet aan de eisen voor Teams (o.a. een eigenaar met de juiste licentie)."
        }
    } else {
        Write-Host "Groep '$algemeenGroupName' niet gevonden na alle stappen. Kan Teams niet activeren." -ForegroundColor Red
    }

} # Sluitende haakje voor hoofd try-blok
catch {
    Write-Error "Er is een kritieke fout opgetreden tijdens de uitvoering van het script: $($_.Exception.Message)"
    $_ | Format-List -Force # uncomment voor meer foutdetails
}
finally {
    # Verbreek alle verbindingen netjes aan het einde van het script
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Write-Host "`nVerbinding met Microsoft Graph wordt verbroken."
        Disconnect-MgGraph
    }
    if (Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue) {
        Write-Host "Verbinding met Microsoft.Online.SharePoint.PowerShell service wordt verbroken."
        Disconnect-SPOService -ErrorAction SilentlyContinue 
    }
    # Belangrijk: Reset de omgevingsvariabele aan het einde, anders kan het andere scripts beïnvloeden
    [Environment]::SetEnvironmentVariable("MSAL_PS_BROWSER_AUTH_DISABLED", $null, "Process")
    Write-Host "`nScript voltooid." -ForegroundColor DarkCyan
}