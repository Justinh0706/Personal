<#
.Omschrijving
Script om een standaard Microsoft 365 omgeving in te richten
Dit script is bewust eenvoudig geschreven, zodat hij ook makkelijk aan te passen is voor iemand met alleen basiskennis van Powershell (wat overigens ook mijn eigen niveau is)
Verwijder na het aanmaken de gebruikers die niet van toepassing zijn uit Entra

LET OP - BELANGRIJKE INFORMATIE: 
Controleer altijd na het uitvoeren van dit script of de configuratie overeenkomt met de handleiding. 
Met name toewijzingen van licenties, gebruikers en groepen zijn belangrijk om te controleren omdat niets zo veranderlijk is als Microsoft 365 en Azure
 
Dit script gebruikt nu volledig de Microsoft Graph PowerShell SDK, wat de aanbevolen methode is.
#>

Set-ExecutionPolicy -scope CurrentUser bypass

# Wijzig de onderstaande waardes voor dit project (Let op, vul bij supracomlab.onmicrosoft.com het primaire domainnaam in van de praktijk bijv. beukenlaan.nl)
$domainname = "deeznutz.nl"
$praktijknaam = "Jouw Praktijknaam"  # Pas dit aan naar de naam van de praktijk

$PasswordProfile = @{
  Password = 'Cartwheel-Stool1-Bobbing'
  ForceChangePasswordNextSignIn = $false
  ForceChangePasswordNextSignInWithMfa = $true
}



    
# De vaste weergavenaam en mailnickname/URL voor de groep "Algemeen"
$algemeenGroupName = "Algemeen"
$algemeenGroupMailNickname = "algemeen"

# Lijsten van generieke/gedeelde gebruikers die aangemaakt moeten worden.
$behandelkamerUsers = 1..5 | ForEach-Object { "Behandelkamer$_" }
$balieUsers = 1..1 | ForEach-Object { "Balie$_" }
$backofficeUsers = 1..2 | ForEach-Object { "Backoffice$_" }
$kantoorUsers = 1..1 | ForEach-Object { "Kantoor$_" }
$rontgenUsers = 1..1 | ForEach-Object { "Rontgen$_" }
$sterilisatieUsers = 1..1 | ForEach-Object { "Sterilisatie$_" }

$allGenericUsers = $behandelkamerUsers + $balieUsers + $backofficeUsers + $kantoorUsers + $rontgenUsers + $sterilisatieUsers

####################################################### Hieronder niets aanpassen ##########################################################################

# Importeer benodigde modules (probeer, maar faal niet stil als gebruiker installatie overslaat)
try {
    Import-Module $modules -Force -ErrorAction Stop
} catch {
    Write-Warning "Microsoft.Graph modules konden niet geïmporteerd worden: $($_.Exception.Message)"
    if ($reinstall -eq 'Y') { throw } else { Write-Host "Doorgaan zonder geïmporteerde modules. Sommige functionaliteit kan ontbreken." -ForegroundColor Yellow }
}
# Begin van het hoofdscript



try {
    # Verbinden met Microsoft Graph
    Write-Host "`nVerbinding maken met Microsoft Graph..." -ForegroundColor Yellow
    # Probeer eerst de compatibele helper; valt terug op Connect-MgGraph indien niet beschikbaar
    if (Get-Command -Name 'Connect-MgGraph -EnsureInteractive' -ErrorAction SilentlyContinue) {
        Connect-MgGraph-EnsureInteractive -Scopes @("Group.ReadWrite.All", "Directory.ReadWrite.All", "User.Read.All") -ErrorAction Stop
    }
    else {
        Write-Host "Info: 'Connect-MgGraph-EnsureInteractive' niet gevonden; gebruik 'Connect-MgGraph'." -ForegroundColor Yellow
        Connect-MgGraph -Scopes @("Group.ReadWrite.All", "Directory.ReadWrite.All", "User.Read.All") -ErrorAction Stop
    }
    Write-Host "Verbonden met Microsoft Graph." -ForegroundColor Green
    
    # Aanmaken van de Microsoft 365 groep 'Algemeen'
    Write-Host "`nStart poging tot aanmaken van Microsoft 365 groep '$algemeenGroupName'." -ForegroundColor DarkYellow
    $newAlgemeenGroup = $null 
    try {
        
        $newGroupParams = @{
            DisplayName                 = $algemeenGroupName
            MailNickname                = $algemeenGroupMailNickname
            MailEnabled                 = $True
            SecurityEnabled             = $True
            GroupTypes                  = @("DynamicMembership", "Unified")
            MembershipRule              = '(user.userType -eq "Member")'
            MembershipRuleProcessingState = 'On'
        }

        $newAlgemeenGroup = New-MgGroup @newGroupParams -ErrorAction Stop 

        if ($newAlgemeenGroup) {
            Write-Host "Groep '$algemeenGroupName' succesvol aangemaakt (ID: $($newAlgemeenGroup.Id))." -ForegroundColor Green
            Start-Sleep -Seconds 5 
        } else {
            throw "New-MgGroup gaf geen object terug voor '$algemeenGroupName', hoewel ErrorAction Stop was ingesteld."
        }
    } catch {
        Write-Error "Kritieke fout bij het opnieuw aanmaken van de groep '$algemeenGroupName': $($_.Exception.Message)"
        Write-Warning "Controleer de oorzaak van deze fout (bijv. rechten, naam al in gebruik maar niet in prullenbak zichtbaar, etc.)."
        throw 
    }
    
    # Extra check om te bevestigen dat de groep is aangemaakt
    if (-not $newAlgemeenGroup) {
        throw "De Microsoft 365 groep '$algemeenGroupName' is niet succesvol aangemaakt na alle pogingen. Script afgebroken."
    }

# Wacht en check dat de SharePoint site voor de nieuwe groep is geprovisioneerd met de correcte URL
    Write-Host "`nControleren of de SharePoint site voor de nieuwe groep is geprovisioneerd met de correcte URL..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15 # Geef de groep even de tijd om te starten met provisioning





    # Standaard lijst met accounts aanmaken.
    Write-Host "`nAanmaken van standaard gebruikersaccounts..." -ForegroundColor Yellow
    # Behandelkamer
    # --- Stap 2: Gebruikers aanmaken ---
Write-Host "`nStap 2: Gebruikers aanmaken..." -ForegroundColor Yellow

foreach ($userName in $allGenericUsers) {
    $displayName = "$userName | $praktijknaam"
    if (Get-MgUser -Filter "userPrincipalName eq '$($userName)@$domainname'") { Write-Host "  - Gebruiker '$displayName' bestaat al, wordt overgeslagen."; continue }
    try { New-MgUser -DisplayName $displayName -UserPrincipalName "$($userName)@$domainname" -MailNickName $userName -AccountEnabled:$true -PasswordProfile $PasswordProfile; Write-Host "  ✅ Gebruiker '$displayName' succesvol aangemaakt." }
    catch { Write-Host "  ❌ Fout bij aanmaken van gebruiker '$displayName': $($_.Exception.Message)" -ForegroundColor Red }
}
    Write-Host "Standaard gebruikersaccounts succesvol aangemaakt." -ForegroundColor Green
    Start-Sleep -Seconds 10 # Korte pauze na het aanmaken van gebruikers

    #Aanmaken van Security groepen en Microsoft 365 Groepen (Unified)
    Write-Host "`nAanmaken van standaard Security groepen en Microsoft 365 groepen..." -ForegroundColor Yellow
    New-MgGroup -DisplayName "Users-Email" -MailEnabled:$false -MailNickName "Users-Email" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Users-Shared" -MailEnabled:$false -MailNickName "Users-Shared" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Users-Personal" -MailEnabled:$false -MailNickName "Users-Personal" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Application-Microsoft365" -MailEnabled:$false -MailNickName "Application-Microsoft365" -SecurityEnabled:$true
    
    #Aanmaken van de Role Groups
    New-MgGroup -DisplayName "Roles-RDPEnabled" -MailEnabled:$false -MailNickName "Roles-RDPEnabled" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Roles-LocalAdmin" -MailEnabled:$false -MailNickName "Roles-LocalAdmin" -SecurityEnabled:$true

    # Nieuwe Microsoft 365 groep "Management"
    New-MgGroup -DisplayName "Management" -MailEnabled:$True -MailNickName "management" -SecurityEnabled:$True -GroupTypes @("Unified")
    
    Write-Host "Standaard Security groepen en Microsoft 365 groepen succesvol aangemaakt." -ForegroundColor Green

    #Aanmaken Dynamische User groepen
    Write-Host "`nAanmaken van Dynamische User groepen..." -ForegroundColor Yellow

    # Dynamische regel voor Users-AllUsers: alle Member gebruikers (combinatie van objectId check en userType check)
    New-MgGroup -DisplayName "Users-AllUsers" -Description "Alle Users" -MailEnabled:$false -MailNickname "AllUsers" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(user.objectId -ne null) and (user.userType -eq "Member")' -MembershipRuleProcessingState "On"
    Write-Host "Dynamische User groepen succesvol aangemaakt." -ForegroundColor Green

    #Dynamische Device groepen
    Write-Host "Aanmaken van Dynamische Device groepen..." -ForegroundColor Yellow
    New-MgGroup -displayname "Devices-EntraJoined" -Description "Entra joined devices" -MailEnabled:$false -MailNickName "Entrajoined" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.deviceTrustType -eq "AzureAD") -or (device.deviceTrustType -eq "ServerAD")' -MembershipRuleProcessingState "On"
    New-MgGroup -displayname "Devices-Autopilot" -Description "Autopilot joined devices" -MailEnabled:$false -MailNickName "Autopilotjoined" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.devicePhysicalIDs -any _ -contains "[ZTDId]")' -MembershipRuleProcessingState "On"
    New-MgGroup -displayname "Devices-Managed" -Description "Devices that start with SID-" -MailEnabled:$false -MailNickName "SID-hostnames" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.displayName -startsWith "SID-")' -MembershipRuleProcessingState "On"
    Write-Host "Dynamische Device groepen succesvol aangemaakt." -ForegroundColor Green

    #Licentie Groepen
    Write-Host "`nAanmaken van Licentie Groepen..." -ForegroundColor Yellow
    New-MgGroup -DisplayName "License-BusinessPremium" -Description "Groep om Business Premium toe te wijzen aan gebruikers" -MailEnabled:$false -MailNickname "BPremium" -SecurityEnabled:$true 
    New-MgGroup -DisplayName "License-ExchangeOnline" -Description "Groep om Exchange Online toe te wijzen aan gebruikers" -MailEnabled:$false -MailNickname "Exchange" -SecurityEnabled:$true 
    Write-Host "Licentie Groepen succesvol aangemaakt." -ForegroundColor Green

    # Wacht na het aanmaken van groepen voor propagatie
    Write-Host "`nWacht 30 seconden voor groepspropagatie..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    #Vraag naar een gebruiker met een Business Premium licentie
    $OutputYN = Read-Host "Voeg nu eerst handmatig een Business Premium licentie toe aan een gebruiker, Voer Y in wanneer dit gelukt is (Y/N)"
    If ($OutputYN -ne "Y" -and $OutputYN -ne "N") {
        Do {
            $OutputYN = Read-Host "Geef alstublieft 'Y' voor ja of 'N' voor nee in."
        } While ($OutputYN -ne "Y" -and $OutputYN -ne "N")
    }
    
    if ($OutputYN -eq "Y") { 
        $targetGroupName_License = "License-BusinessPremium"
        $businessPremiumLicenseDisplayName = "Microsoft 365 Business Premium"

        # Stap A: Zoek de doelgroep License-BusinessPremium
        Write-Host "`nStap A: Zoeken naar de doelgroep '$targetGroupName_License'..." -ForegroundColor Yellow
        $targetGroup_License = Get-MgGroup -Filter "displayName eq '$targetGroupName_License'" | Select-Object -First 1
        
        if (-not $targetGroup_License) {
            throw "De groep met de naam '$targetGroupName_License' kon niet worden gevonden. Zorg dat deze bestaat."
        }
        Write-Host "Groep gevonden: $($targetGroup_License.DisplayName) (ID: $($targetGroup_License.Id))" -ForegroundColor Green

        # Stap B: Bepaal de Business Premium SkuId via een referentiegebruiker
        $businessPremiumSkuIdToUse_License = $null
        while ($null -eq $businessPremiumSkuIdToUse_License) {
            Write-Host "`nStap B: '$businessPremiumLicenseDisplayName' SkuId bepalen voor licentietoewijzing aan groep." -ForegroundColor Yellow
            $referenceUserUpn = Read-Host "Geef de UPN (e-mailadres) op van EEN GEBRUIKER die al de '$businessPremiumLicenseDisplayName' licentie heeft"

            if ([string]::IsNullOrWhiteSpace($referenceUserUpn)) {
                Write-Warning "Invoer is leeg. Probeer het opnieuw."
                continue
            }

            try {
                $refUser = Get-MgUser -UserId $referenceUserUpn -Property "id,displayName,assignedLicenses,accountEnabled" -ErrorAction Stop
            }
            catch {
                Write-Warning "Gebruiker '$referenceUserUpn' kon niet worden gevonden. Controleer het e-mailadres en probeer het opnieuw."
                continue
            }

            if ($refUser.AccountEnabled -ne $true) {
                Write-Warning "Gebruiker '$($refUser.DisplayName)' is niet actief (geblokkeerd). Kies een actieve gebruiker."
                continue
            }

            $allAssignedSkuIds = $null
            if ($null -ne $refUser.AssignedLicenses -and $refUser.AssignedLicenses.Count -gt 0) {
                $allAssignedSkuIds = @($refUser.AssignedLicenses | Select-Object -ExpandProperty SkuId)
                Write-Host "`nDe volgende SkuId's zijn toegewezen aan '$($refUser.DisplayName)':" -ForegroundColor Cyan
                $allAssignedSkuIds | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
            } else {
                Write-Warning "Gebruiker '$($refUser.DisplayName)' heeft geen direct toegewezen licenties. Kies een andere gebruiker."
                continue
            }
            
            # Neem automatisch de EERSTE SKU ID van de gebruiker en zet deze om naar schone string
            $businessPremiumSkuIdToUse_License = ([string]$allAssignedSkuIds[0]).Trim()
            Write-Host "`nBusiness Premium SkuId automatisch geselecteerd: $businessPremiumSkuIdToUse_License" -ForegroundColor Green
        } 
        
        # Stap C: Licentie toewijzen aan de groep License-BusinessPremium
        Write-Host "`nStap C: Licentie '$businessPremiumLicenseDisplayName' (SkuId: $businessPremiumSkuIdToUse_License) toewijzen aan groep '$targetGroupName_License'..." -ForegroundColor Yellow
        
        $currentGroupSkus = (Get-MgGroup -GroupId $targetGroup_License.Id -Property "assignedLicenses").AssignedLicenses.SkuId

        if ($currentGroupSkus -contains $businessPremiumSkuIdToUse_License) {
            Write-Host "Licentie '$businessPremiumLicenseDisplayName' is al toegewezen aan groep '$targetGroupName_License'." -ForegroundColor Cyan
        } else {
            # gebruik direct REST API aanroep voor meer controle
            $groupId = $targetGroup_License.Id
            $skuString = $businessPremiumSkuIdToUse_License
            
            $body = @{
                addLicenses = @(
                    @{
                        skuId = $skuString
                    }
                )
                removeLicenses = @()
            } | ConvertTo-Json -Depth 5
            
            Write-Host "Body being sent: $body" -ForegroundColor DarkGray
            
            try {
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/assignLicense" -Body $body -ErrorAction Stop | Out-Null
                Write-Host "Licentie '$businessPremiumLicenseDisplayName' succesvol toegewezen aan groep '$targetGroupName_License' via REST API." -ForegroundColor Green
            }
            catch {
                Write-Warning "REST API aanroep mislukt, proberen met cmdlet..."
                Set-MgGroupLicense -GroupId $groupId -AddLicenses @{ skuId = $skuString } -RemoveLicenses @()
                Write-Host "Licentie '$businessPremiumLicenseDisplayName' succesvol toegewezen aan groep '$targetGroupName_License' via cmdlet." -ForegroundColor Green
            }
        }
    } 
    else {
        Write-Host "Licentietoewijzing aan groep '$targetGroupName_License' overgeslagen zoals gevraagd." -ForegroundColor Yellow
    }

    Write-Host "`nWacht 30 seconden na licentietoewijzing..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30 
    

    ##### Hier word een owner toegevoegd aan de algemeen groep zodat Teams geactiveerd kan worden. ####
    $businessPremiumLicenseDisplayName_Owner = "Microsoft 365 Business Premium" 
    $groupNameToSearch_Owner = "Algemeen" # De statische weergavenaam van de groep

    # Haal de groep opnieuw op, voor zekerheid, na eventuele heraanmaak
    $algemeenGroupForOwner = Get-MgGroup -Filter "displayName eq '$groupNameToSearch_Owner'" | Select-Object -First 1

    if (-not $algemeenGroupForOwner) {
        throw "Groep '$groupNameToSearch_Owner' is na aanmaak/validatie niet meer gevonden. Kan geen eigenaar toevoegen."
    }

    # Stap A (Owner): Vraag om de groepseigenaar en valideer deze in een lus
    $validOwner = $null
    $businessPremiumSkuIdToUse_Owner = $null 

    while ($null -eq $validOwner) {
        Write-Host "`nStap A: Groepseigenaar selecteren en licentie valideren voor groep '$groupNameToSearch_Owner'." -ForegroundColor Yellow
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

        # Validatie 2: Toon de licenties en gebruik automatisch dezelfde SkuId als voor de groepslicentie
        $assignedSkuIds_Owner = $null
        if ($null -ne $potentialOwner.AssignedLicenses -and $potentialOwner.AssignedLicenses.Count -gt 0) {
            $assignedSkuIds_Owner = @($potentialOwner.AssignedLicenses | Select-Object -ExpandProperty SkuId)
            Write-Host "`nDe volgende SkuId's zijn toegewezen aan '$($potentialOwner.DisplayName)':" -ForegroundColor Cyan
            $assignedSkuIds_Owner | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
        } else {
            Write-Warning "Gebruiker '$($potentialOwner.DisplayName)' heeft geen direct toegewezen licenties. Kies een andere gebruiker."
            continue
        }
        
        # Controleer of de gebruiker dezelfde SkuId heeft als die we al hebben bepaald voor de groepslicentie
        if ($assignedSkuIds_Owner -contains $businessPremiumSkuIdToUse_License) {
            $businessPremiumSkuIdToUse_Owner = $businessPremiumSkuIdToUse_License
            Write-Host "`nDezelfde Business Premium licentie (SkuId: $businessPremiumSkuIdToUse_Owner) is automatisch geselecteerd." -ForegroundColor Green
            $validOwner = $potentialOwner 
        } else {
            Write-Warning "Gebruiker '$($potentialOwner.DisplayName)' heeft NIET dezelfde Business Premium licentie (SkuId: $businessPremiumSkuIdToUse_License). Probeer een andere gebruiker."
            continue
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

    ####Teams Activeren voor Algemeen####
    $teamsGroup = Get-MgGroup -Filter "displayName eq '$algemeenGroupName'" | Select-Object -First 1

    if ($teamsGroup) {
        try {
            
            # Teams activeren op de bestaande Microsoft 365 groep via Graph API
    $uri = "https://graph.microsoft.com/v1.0/groups/$($teamsGroup.Id)/team"
    $body = @{
        memberSettings = @{
            allowCreateUpdateChannels = $true
        }
        messagingSettings = @{
            allowUserEditMessages = $true
        }
    } | ConvertTo-Json -Depth 5

    Invoke-MgGraphRequest -Method PUT -Uri $uri -Body $body -ErrorAction Stop

            Write-Host "Teams succesvol geactiveerd voor groep '$($teamsGroup.DisplayName)'" -ForegroundColor Green
        } catch {
            Write-Warning "Fout bij activeren van Teams op groep '$($teamsGroup.DisplayName)': $($_.Exception.Message)"
            Write-Warning "Controleer of de groep voldoet aan de eisen voor Teams (o.a. een eigenaar met de juiste licentie)."
        }
    } else {
        Write-Host "Groep '$algemeenGroupName' niet gevonden na alle stappen. Kan Teams niet activeren." -ForegroundColor Red
    }

    ##### Eigenaar toevoegen aan Management groep en Teams activeren ####
    Write-Host "`n--- Management Groep Configuratie ---" -ForegroundColor Cyan
    $managementGroupName = "Management"
    
    # Haal de Management groep op
    $managementGroupForOwner = Get-MgGroup -Filter "displayName eq '$managementGroupName'" | Select-Object -First 1

    if (-not $managementGroupForOwner) {
        Write-Warning "Groep '$managementGroupName' kon niet worden gevonden. Management configuratie overgeslagen."
    } else {
        Write-Host "`nDe dezelfde gebruiker '$($validOwner.DisplayName)' wordt ook eigenaar van de groep '$managementGroupName'." -ForegroundColor Yellow
        
        # Controleer of de gebruiker al eigenaar is en voeg toe indien nodig
        $currentManagementOwners = Get-MgGroupOwner -GroupId $managementGroupForOwner.Id
        
        if ($validOwner.Id -in $currentManagementOwners.Id) {
            Write-Host "$($validOwner.DisplayName) is al eigenaar van de groep '$($managementGroupForOwner.DisplayName)'." -ForegroundColor Cyan
        } else {
            try {
                New-MgGroupOwner -GroupId $managementGroupForOwner.Id -DirectoryObjectId $validOwner.Id
                Write-Host "SUCCES! '$($validOwner.DisplayName)' is nu eigenaar van de groep '$($managementGroupForOwner.DisplayName)'." -ForegroundColor Green
            } catch {
                Write-Warning "Fout bij toevoegen van eigenaar aan Management groep: $($_.Exception.Message)"
            }
        }

        Start-Sleep -Seconds 5

        # Teams activeren op de Management groep
        Write-Host "`nTeams activeren voor groep '$managementGroupName'..." -ForegroundColor Yellow
        try {
            $uri = "https://graph.microsoft.com/v1.0/groups/$($managementGroupForOwner.Id)/team"
            $body = @{
                memberSettings = @{
                    allowCreateUpdateChannels = $true
                }
                messagingSettings = @{
                    allowUserEditMessages = $true
                }
            } | ConvertTo-Json -Depth 5

            Invoke-MgGraphRequest -Method PUT -Uri $uri -Body $body -ErrorAction Stop
            Write-Host "Teams succesvol geactiveerd voor groep '$($managementGroupForOwner.DisplayName)'" -ForegroundColor Green
        } catch {
            Write-Warning "Fout bij activeren van Teams op groep '$($managementGroupForOwner.DisplayName)': $($_.Exception.Message)"
            Write-Warning "Controleer of de groep voldoet aan de eisen voor Teams (o.a. een eigenaar met de juiste licentie)."
        }
    }

}
catch {
    Write-Error "Er is een kritieke fout opgetreden tijdens de uitvoering van het script: $($_.Exception.Message)"
    Write-Error ($_.Exception | Out-String)
}
finally {
    # Verbreek alle verbindingen netjes aan het einde van het script
    try {
        if (Get-MgContext -ErrorAction SilentlyContinue) {
            Write-Host "`nVerbinding met Microsoft Graph wordt verbroken."
            Disconnect-MgGraph
        }
    } catch {
        Write-Warning "Kon Microsoft Graph niet automatisch ontkoppelen: $($_.Exception.Message)"
    }
    # Belangrijk: Reset de omgevingsvariabele aan het einde, anders kan het andere scripts beïnvloeden
    
    Write-Host "`nScript voltooid." -ForegroundColor DarkCyan
}