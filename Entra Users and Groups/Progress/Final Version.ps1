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

$PasswordProfile = @{
  Password = 'WerkplekWachtwoord123'
  ForceChangePasswordNextSignIn = $false
  ForceChangePasswordNextSignInWithMfa = $true
}


#Persoonlijke gebruikers aanmaken (Voor department kan er ingesteld worden wie toegang heeft tot welke Sharepoint site). Pas op met wie je hier tot toegang geeft!

$personal = @( 
    @{Voorletter = "J"; Voornaam = "Jan"; Achternaam = "Hans"; },
    @{Voorletter = "A"; Voornaam = "Pieter"; Achternaam = "Jansen"; }
    
        
    )


#De Microsoft 365 groep Algemeen wordt verwijderd zodat hier een syntax aan toegevoegd kan worden. Hier moet de URL voor aangepast worden zodat de URL niet in gebruik blijft door de oude groep.
#Vul hier de URL in

# BELANGRIJK: VERVANG DEZE WAARDEN MET JOUW TENANT SPECIFIEKE URL'S!
# Deze URL wordt gebruikt om connectie te maken met het Sharepoint Admin center
$adminUrl = "https://deeznutsnl-admin.sharepoint.com" # Bijv. https://supracombv-admin.sharepoint.com

# Hier wordt de URL omgezet (Oude URL van Algemeen wordt omgeleid). Dit is de URL die vrij moet komen.
$oldUrlSharePointSite = "https://deeznutsnl.sharepoint.com/sites/algemeen" # Bijv. https://supracombv.sharepoint.com/sites/algemeen
$newUrlSharePointSite = "https://deeznutsnl.sharepoint.com/sites/willbedeleted" # Bijv. https://supracombv.sharepoint.com/sites/willbedeleted (Site waar de inhoud van oude Algemeen naar verhuist)

# De vaste weergavenaam en mailnickname/URL voor de groep "Algemeen" (deze wordt straks opnieuw aangemaakt)
$algemeenGroupName = "Algemeen"
$algemeenGroupMailNickname = "algemeen"
$fullDesiredSharePointSiteUrl_Algemeen = "https://deeznutz.nl.sharepoint.com/sites/$algemeenGroupMailNickname" # Let op: dit is dezelfde URL als $oldUrlSharePointSite

# Installatie/Update van Microsoft.Graph modules (commentaar verwijderd om uit te voeren indien nodig)
# Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber

# Installatie/Update van Microsoft.Online.SharePoint.PowerShell (commentaar verwijderd om uit te voeren indien nodig)
# Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force


# Importeer benodigde modules
# Specifiek importeren van submodules voor betere prestaties
Import-Module -Name Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop # ErrorAction Stop voor SPO modules
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop
Import-Module Microsoft.Graph.Teams -ErrorAction Stop
Import-Module Microsoft.Graph.DirectoryObjects -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop

####################################################### Hieronder niets aanpassen ##########################################################################

# --- Hoofd Try-Catch-Finally blok voor het hele script (voor robuuste foutafhandeling en verbindingen) ---
try {
    # Connect met SharePoint Online Admin Center (voor Start-SPOSiteRename)
    Write-Host "`nVerbinding maken met SharePoint Online Admin Center (voor site omleiding en opruimen)..." -ForegroundColor Yellow
    Write-Warning "Zorg ervoor dat het account waarmee u inlogt minimaal de rol 'SharePoint Administrator' heeft in Microsoft 365."
    Connect-SPOService -Url $adminUrl -ErrorAction Stop
    Write-Host "Verbonden met SharePoint Online Admin Center." -ForegroundColor Green

    # --- Start: Sectie voor het omleiden en opschonen van de oude SharePoint URL "Algemeen" ---
    Write-Host "`nControleren en eventueel omleiden van oude SharePoint site URL '$oldUrlSharePointSite'..." -ForegroundColor Yellow
    try {
        $siteFoundAndRenamed = $false
        
        # Controleer of de oude site als actieve site bestaat
        $oldSiteSPO = Get-SPOSite -Identity $oldUrlSharePointSite -ErrorAction SilentlyContinue
        
        if ($oldSiteSPO) {
            Write-Host "Oude site '$oldUrlSharePointSite' gevonden. Omleiden naar '$newUrlSharePointSite'..." -ForegroundColor Yellow
            Start-SPOSiteRename -Identity $oldUrlSharePointSite -NewSiteUrl $newUrlSharePointSite -ErrorAction Stop
            Write-Host "Oude site URL succesvol omgeleid. De inhoud is nu op '$newUrlSharePointSite'." -ForegroundColor Green
            Start-Sleep -Seconds 15 # Geef de tijd voor de omleiding om te propageren
            $siteFoundAndRenamed = $true
        } else {
            Write-Host "Oude site '$oldUrlSharePointSite' niet gevonden als actieve site. Geen omleiding nodig." -ForegroundColor Cyan
        }

        # --- Expliciete verwijdering van de OUDE URL ($oldUrlSharePointSite) ---
        # Deze stappen zorgen ervoor dat $oldUrlSharePointSite (de toekomstige URL van de nieuwe groep) volledig vrij is.

        Write-Host "Verifiëren en indien nodig permanent verwijderen van '$oldUrlSharePointSite'..." -ForegroundColor DarkYellow
        
        # De door jou toegevoegde lange sleep voor mogelijke propagatie
        Start-Sleep -Seconds 80 
        
        # 1. Probeer de site te verwijderen als deze (ondanks omleiding/niet vinden) nog als actieve site bestaat
        try {
            $checkActiveSiteAgain = Get-SPOSite -Identity $oldUrlSharePointSite -ErrorAction SilentlyContinue
            if ($checkActiveSiteAgain) {
                Write-Warning "Site '$oldUrlSharePointSite' bestaat nog als actieve site. Probeer nu te verwijderen..."
                Remove-SPOSite -Identity $oldUrlSharePointSite -Confirm:$false -ErrorAction Stop
                Write-Host "Actieve site '$oldUrlSharePointSite' succesvol verwijderd." -ForegroundColor Green
                Start-Sleep -Seconds 5 # Korte pauze
            } else {
                Write-Host "Site '$oldUrlSharePointSite' niet gevonden als actieve site, goed." -ForegroundColor Green
            }
        } catch {
            Write-Warning "Fout bij verwijderen van actieve site '$oldUrlSharePointSite': $($_.Exception.Message)"
        }

        # De door jou toegevoegde sleep hier
        Start-Sleep -Seconds 30

        # N.B. De expliciete Remove-SPODeletedSite hier is verwijderd, dit wordt nu later in de wachtlus afgehandeld.

    } catch {
        Write-Error "Kritieke fout bij het omleiden of opschonen van SharePoint site '$oldUrlSharePointSite': $($_.Exception.Message)"
        Write-Warning "Script zal proberen verder te gaan, maar controleer handmatig of '$oldUrlSharePointSite' nu vrij is."
    }

    # Verbreek de SPO Service connectie voor nu, want Graph connectie volgt
    Disconnect-SPOService

    # --- Einde: Sectie voor het omleiden en opschonen van de oude SharePoint URL "Algemeen" ---


    # Verbinden met Microsoft Graph
    Write-Host "`nVerbinding maken met Microsoft Graph..." -ForegroundColor Yellow
    # Zorg dat de benodigde scopes hier aanwezig zijn voor alle Graph-operaties, inclusief verwijderde items.
    Connect-MgGraph -scopes "Group.ReadWrite.All", "Directory.ReadWrite.All", "User.Read.All" -ErrorAction Stop
    Write-Host "Verbonden met Microsoft Graph." -ForegroundColor Green
    

    # Standaard lijst met accounts aanmaken.
    Write-Host "`nAanmaken van standaard gebruikersaccounts..." -ForegroundColor Yellow
    # Behandelkamer
    New-MgUser -DisplayName "Behandelkamer1" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer1" -UserPrincipalName "Behandelkamer1@$domainname" 
    New-MgUser -DisplayName "Behandelkamer2" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer2" -UserPrincipalName "Behandelkamer2@$domainname" 
    New-MgUser -DisplayName "Behandelkamer3" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer3" -UserPrincipalName "Behandelkamer3@$domainname" 
    New-MgUser -DisplayName "Behandelkamer4" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer4" -UserPrincipalName "Behandelkamer4@$domainname"
    New-MgUser -DisplayName "Behandelkamer5" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer5" -UserPrincipalName "Behandelkamer5@$domainname" 
    New-MgUser -DisplayName "Behandelkamer6" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer6" -UserPrincipalName "Behandelkamer6@$domainname" 
    New-MgUser -DisplayName "Behandelkamer7" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer7" -UserPrincipalName "Behandelkamer7@$domainname"
    New-MgUser -DisplayName "Behandelkamer8" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Behandelkamer8" -UserPrincipalName "Behandelkamer8@$domainname"

    #Balie
    New-MgUser -DisplayName "Balie1" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Balie1" -UserPrincipalName "Balie1@$domainname"
    New-MgUser -DisplayName "Balie2" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Balie2" -UserPrincipalName "Balie2@$domainname"
    New-MgUser -DisplayName "Balie3" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Balie3" -UserPrincipalName "Balie3@$domainname" 
    New-MgUser -DisplayName "Balie4" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Balie4" -UserPrincipalName "Balie4@$domainname"

    #Backoffice
    New-MgUser -DisplayName "Backoffice1" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Backoffice1" -UserPrincipalName "Backoffice1@$domainname" 
    New-MgUser -DisplayName "Backoffice2" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Backoffice2" -UserPrincipalName "Backoffice2@$domainname"

    #Kantoor
    New-MgUser -DisplayName "Kantoor1" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Kantoor1" -UserPrincipalName "Kantoor1@$domainname"
    New-MgUser -DisplayName "Kantoor2" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Kantoor2" -UserPrincipalName "Kantoor2@$domainname"

    #Rontgen
    New-MgUser -DisplayName "Rontgen1" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Rontgen1" -UserPrincipalName "Rontgen1@$domainname"

    #Sterilisatie
    New-MgUser -DisplayName "Sterilisatie1" -PasswordProfile $PasswordProfile -AccountEnabled:$true -MailNickName "Sterilisatie1" -UserPrincipalName "Sterilisatie1@$domainname"

    #Creatie van Persoonlijke users (Dit kan uitgeschakeld worden als dit niet nodig is door een # voor de string te zetten).
    foreach ($user in $personal) {
        $displayName = "$($user.Voornaam) $($user.Achternaam)"
        $userPrincipalName = "$($user.Voorletter).$($user.Achternaam)@$domainname" # Gebruik $domainname
        $mailNickname = "$($user.Voornaam)"

        New-MgUser `
            -DisplayName $displayName `
            -GivenName $user.Voornaam `
            -Surname $user.Achternaam `
            -PasswordProfile $PasswordProfile `
            -MailNickName $mailNickname `
            -UserPrincipalName $userPrincipalName `
            -AccountEnabled:$true
    }
    Write-Host "Standaard gebruikersaccounts succesvol aangemaakt." -ForegroundColor Green
    Start-Sleep -Seconds 10 # Korte pauze na het aanmaken van gebruikers

    #Aanmaken van Security groups (NIET dynamisch zoals in eerdere versies)
    Write-Host "`nAanmaken van standaard Security groepen..." -ForegroundColor Yellow
    New-MgGroup -DisplayName "Users-Email" -MailEnabled:$false -MailNickName "Users-Email" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Users-RDPEnabled" -MailEnabled:$false -MailNickName "Users-RDPEnabled" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Users-Shared" -MailEnabled:$false -MailNickName "Users-Shared" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Users-Personal" -MailEnabled:$false -MailNickName "Users-Personal" -SecurityEnabled:$true
    New-MgGroup -DisplayName "Application-Microsoft365" -MailEnabled:$false -MailNickName "Application-Microsoft365" -SecurityEnabled:$true
    Write-Host "Standaard Security groepen succesvol aangemaakt." -ForegroundColor Green

    #Aanmaken Dynamische User groepen
    Write-Host "`nAanmaken van Dynamische User groepen..." -ForegroundColor Yellow
    # Dynamische regel voor Users-AllUsers: alle Member gebruikers (combinatie van objectId check en userType check)
    New-MgGroup -DisplayName "Users-AllUsers" -Description "Alle Users" -MailEnabled:$false -MailNickname "AllUsers" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(user.objectId -ne null) and (user.userType -eq "Member")' -MembershipRuleProcessingState "On"
    Write-Host "Dynamische User groepen succesvol aangemaakt." -ForegroundColor Green

    #Dynamische Device groepen
    Write-Host "`nAanmaken van Dynamische Device groepen..." -ForegroundColor Yellow
    New-MgGroup -displayname "Devices-EntraJoined" -Description "Entra joined devices" -MailEnabled:$false -MailNickName "Entrajoined" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.deviceTrustType -eq "AzureAD") -or (device.deviceTrustType -eq "ServerAD")' -MembershipRuleProcessingState "On"
    New-MgGroup -displayname "Devices-Autopilot" -Description "Autopilot joined devices" -MailEnabled:$false -MailNickName "Autopilotjoined" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.devicePhysicalIDs -any _ -contains "[ZTDId]")' -MembershipRuleProcessingState "On"
    Write-Host "Dynamische Device groepen succesvol aangemaakt." -ForegroundColor Green

    #Licentie Groepen
    Write-Host "`nAanmaken van Licentie Groepen..." -ForegroundColor Yellow
    New-MgGroup -DisplayName "License-BusinessPremium" -Description "Groep om Business Premium toe te wijzen aan gebruikers" -MailEnabled:$false -MailNickname "BPremium" -SecurityEnabled:$true 
    New-MgGroup -DisplayName "License-ExchangeOnline" -Description "Groep om Exchange Online toe te wijzen aan gebruikers" -MailEnabled:$false -MailNickname "Exchange" -SecurityEnabled:$true 
    Write-Host "Licentie Groepen succesvol aangemaakt." -ForegroundColor Green

    # Wacht na het aanmaken van groepen voor propagatie
    Write-Host "`nWacht 30 seconden voor groepspropagatie..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    # Interactieve prompt voor licentietoewijzing aan License-BusinessPremium
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

        # Stap B: Bepaal de Business Premium SkuId via een referentiegebruiker (interactief)
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
                $allAssignedSkuIds = $refUser.AssignedLicenses | Select-Object -ExpandProperty SkuId
                Write-Host "`nDe volgende SkuId's zijn toegewezen aan '$($refUser.DisplayName)':" -ForegroundColor Cyan
                $allAssignedSkuIds | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
            } else {
                Write-Warning "Gebruiker '$($refUser.DisplayName)' heeft geen direct toegewezen licenties. Kies een andere gebruiker."
                continue
            }
            
            $selectedSkuId = Read-Host "`nKopieer en plak de exacte SkuId hierboven die overeenkomt met '$businessPremiumLicenseDisplayName'"
            
            if ($allAssignedSkuIds -contains $selectedSkuId) {
                $businessPremiumSkuIdToUse_License = $selectedSkuId
                Write-Host "SkuId '$businessPremiumSkuIdToUse_License' geselecteerd voor licentietoewijzing." -ForegroundColor Green
            } else {
                Write-Warning "De ingevoerde SkuId '$selectedSkuId' is NIET gevonden bij de opgegeven gebruiker '$($refUser.DisplayName)'. Probeer het opnieuw."
            }
        }

        # Stap C: Licentie toewijzen aan de groep License-BusinessPremium
        Write-Host "`nStap C: Licentie '$businessPremiumLicenseDisplayName' (SkuId: $businessPremiumSkuIdToUse_License) toewijzen aan groep '$targetGroupName_License'..." -ForegroundColor Yellow
        
        $currentGroupSkus = (Get-MgGroup -GroupId $targetGroup_License.Id -Property "assignedLicenses").AssignedLicenses.SkuId

        if ($currentGroupSkus -contains $businessPremiumSkuIdToUse_License) {
            Write-Host "Licentie '$businessPremiumLicenseDisplayName' is al toegewezen aan groep '$targetGroupName_License'." -ForegroundColor Cyan
        } else {
            Set-MgGroupLicense -GroupId $targetGroup_License.Id `
                               -AddLicenses @{ SkuId = $businessPremiumSkuIdToUse_License } `
                               -RemoveLicenses @() # Laat andere licenties ongemoeid
            Write-Host "Licentie '$businessPremiumLicenseDisplayName' succesvol toegewezen aan groep '$targetGroupName_License'." -ForegroundColor Green
        }
    } # Einde van if ($OutputYN -eq "Y")
    else {
        Write-Host "Licentietoewijzing aan groep '$targetGroupName_License' overgeslagen zoals gevraagd." -ForegroundColor Yellow
    }

    Write-Host "`nWacht 30 seconden na licentietoewijzing..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30 # Wacht na licentietoewijzing


    ##### Bewerken Algemeen schijf  ############
    Write-Host "`nVerwerking van de groep '$algemeenGroupName' en zijn SharePoint URL." -ForegroundColor Yellow

    # Verwijder de oude groep "Algemeen" als deze bestaat in Entra ID (soft-delete via Graph)
    $existingAlgemeenGroup = Get-MgGroup -Filter "displayName eq '$algemeenGroupName'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingAlgemeenGroup) {
        Write-Host "Groep '$algemeenGroupName' gevonden (ID: $($existingAlgemeenGroup.Id)). Verwijderen uit Entra ID (soft-delete via Graph)..." -ForegroundColor Yellow
        Remove-MgGroup -GroupId $existingAlgemeenGroup.Id -Confirm:$false -ErrorAction Stop
        Write-Host "Groep '$algemeenGroupName' is soft-verwijderd uit Entra ID." -ForegroundColor Green
        Start-Sleep -Seconds 30 # Wacht even na soft-delete
    } else {
        Write-Host "Groep '$algemeenGroupName' niet gevonden in Entra ID, geen soft-verwijdering nodig." -ForegroundColor Cyan
    }

    # Probeer de soft-verwijderde Microsoft 365 groep permanent te verwijderen uit Entra ID's prullenbak (via Graph)
    Write-Host "`nControleren en permanent verwijderen van '$algemeenGroupName' uit de Entra ID prullenbak (via Microsoft Graph)..." -ForegroundColor Yellow
    try {
        # Zoek de soft-verwijderde groep via Microsoft Graph's DirectoryObjects cmdlet.
        # N.B.: 'Where-Object' is noodzakelijk omdat Get-MgDirectoryObject -DeletedItem geen -Filter parameter heeft op DisplayName.
        # We filteren expliciet op het type 'group' via '@odata.type'.
        $deletedAlgemeenGroup = Get-MgDirectoryObject -DeletedItem -All | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' -and $_.DisplayName -eq $algemeenGroupName } | Select-Object -First 1
        
        if ($deletedAlgemeenGroup) {
            Write-Host "Verwijderde groep '$algemeenGroupName' (ID: $($deletedAlgemeenGroup.Id)) gevonden in Entra ID prullenbak. Permanent verwijderen..." -ForegroundColor Yellow
            Remove-MgDirectoryDeletedItem -DirectoryObjectId $deletedAlgemeenGroup.Id -Confirm:$false -ErrorAction Stop
            Write-Host "Groep '$algemeenGroupName' permanent verwijderd uit Entra ID prullenbak." -ForegroundColor Green
            Start-Sleep -Seconds 10 # Geef tijd voor propagatie
        } else {
            Write-Host "Groep '$algemeenGroupName' niet gevonden in Entra ID prullenbak, mogelijk al permanent verwijderd of niet eerder bestaan." -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Fout bij permanent verwijderen van de groep uit Entra ID prullenbak via Microsoft Graph: $($_.Exception.Message)"
        Write-Warning "Controleer handmatig of de groep en de bijbehorende SharePoint site volledig zijn verwijderd."
    }

    # --- EINDE: Permanent verwijderen uit Entra ID prullenbak (via Microsoft Graph) ---


    # Belangrijke wacht- en checklus: Controleer of de SharePoint URL echt vrij is
    Write-Host "`nControleren of SharePoint URL '$fullDesiredSharePointSiteUrl_Algemeen' nu echt beschikbaar is..." -ForegroundColor Yellow
    
    # Herverbind met SharePoint Online Service voor de URL checks
    Write-Warning "Zorg ervoor dat het account waarmee u inlogt minimaal de rol 'SharePoint Administrator' heeft in Microsoft 365. Let op eventuele inlogprompts."
    Connect-SPOService -Url $adminUrl -ErrorAction Stop

    $siteStillExists = $true
    $retryCountForClearance = 0
    $maxRetryForClearance = 15 # Max 150 seconden wachten (15 * 10 seconden)
    
    while($siteStillExists -and $retryCountForClearance -lt $maxRetryForClearance) {
        $siteStillExists = $false
        try {
            # Gebruik Get-SPOSite voor actieve sites. 
            $checkActiveSite = Get-SPOSite -Identity $fullDesiredSharePointSiteUrl_Algemeen -ErrorAction SilentlyContinue
            if ($checkActiveSite) { $siteStillExists = $true }
            
            # Controleer ook de verwijderde sites, hoewel M365 groep sites vaak direct naar 2e fase gaan.
            $checkDeletedSite = Get-SPODeletedSite -Identity $fullDesiredSharePointSiteUrl_Algemeen -ErrorAction SilentlyContinue
            if ($checkDeletedSite) { $siteStillExists = $true }

            if($siteStillExists) {
                Write-Host "  URL '$fullDesiredSharePointSiteUrl_Algemeen' is nog in gebruik (actief of prullenbak). Wachten... (Poging $($retryCountForClearance + 1)/$($maxRetryForClearance))" -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                $retryCountForClearance++
            }
        } catch {
            Write-Warning "Fout bij controleren URL beschikbaarheid: $($_.Exception.Message)"
            Start-Sleep -Seconds 5 
            $retryCountForClearance++
        }
    }

    Disconnect-SPOService # Verbreek SPO Service verbinding

    if ($siteStillExists) {
        throw "De gewenste SharePoint URL '$fullDesiredSharePointSiteUrl_Algemeen' is nog steeds in gebruik na verwijdering en omleiding. Kan de groep niet opnieuw aanmaken. Controleer SharePoint handmatig (incl. 2e fase prullenbak)."
    }
    Write-Host "SharePoint URL '$fullDesiredSharePointSiteUrl_Algemeen' is nu beschikbaar." -ForegroundColor Green

    # Maak de Microsoft 365 groep "Algemeen" opnieuw aan
    Write-Host "`nGroep '$algemeenGroupName' opnieuw aanmaken met MailNickname '$algemeenGroupMailNickname'..." -ForegroundColor Yellow
    $newAlgemeenGroup = New-MgGroup -DisplayName $algemeenGroupName `
                                     -MailNickname $algemeenGroupMailNickname `
                                     -MailEnabled:$True `
                                     -SecurityEnabled:$True `
                                     -GroupTypes @("DynamicMembership", "Unified") `
                                     -MembershipRule '(user.userType -eq "Member")' ` # Aangepaste regel syntax voor Graph
                                     -MembershipRuleProcessingState "On" `
                                     -ErrorAction Stop

    if (-not $newAlgemeenGroup) {
        throw "Fout bij het opnieuw aanmaken van de groep '$algemeenGroupName'."
    }
    Write-Host "Groep '$algemeenGroupName' succesvol opnieuw aangemaakt (ID: $($newAlgemeenGroup.Id))." -ForegroundColor Green


    # Wacht en valideer dat de SharePoint site voor de nieuwe groep is geprovisioneerd met de correcte URL
    Write-Host "`nControleren of de SharePoint site voor de nieuwe groep is geprovisioneerd met de correcte URL..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15 # Geef de groep even de tijd om te starten met provisioning
    
    # Herverbind SPO Service voor deze check
    Write-Warning "Zorg ervoor dat het account waarmee u inlogt minimaal de rol 'SharePoint Administrator' heeft in Microsoft 365. Let op eventuele inlogprompts."
    Connect-SPOService -Url $adminUrl -ErrorAction Stop
    
    $siteValidated = $false
    $urlCheckAttempts = 0
    $maxUrlCheckAttempts = 25 # Kan even duren voordat de site live is, 25 pogingen = 250 seconden
    
    while (-not $siteValidated -and $urlCheckAttempts -lt $maxUrlCheckAttempts) {
        $urlCheckAttempts++
        Write-Host "  Poging $($urlCheckAttempts)/$($maxUrlCheckAttempts): Controleren op site '$fullDesiredSharePointSiteUrl_Algemeen'..."
        Start-Sleep -Seconds 10 
        
        try {
            # Gebruik Get-SPOSite om de URL van de nieuw geprovisioneerde site te controleren
            $actualGroupSite = Get-SPOSite -Identity $fullDesiredSharePointSiteUrl_Algemeen -ErrorAction SilentlyContinue
            if ($actualGroupSite) {
                if ($actualGroupSite.Url -eq $fullDesiredSharePointSiteUrl_Algemeen) {
                    $siteValidated = $true
                    Write-Host "SharePoint site URL '$fullDesiredSharePointSiteUrl_Algemeen' succesvol gevalideerd." -ForegroundColor Green
                } else {
                    Write-Warning "Onverwachte SharePoint site URL: '$($actualGroupSite.Url)'. Verwacht: '$fullDesiredSharePointSiteUrl_Algemeen'."
                    throw "SharePoint site voor groep '$algemeenGroupName' heeft niet de gewenste URL. Script afgebroken."
                }
            }
        } catch {
            Write-Warning "Probleem bij controleren van SharePoint site na aanmaken groep: $($_.Exception.Message)"
            # Negeer de fout hier en probeer opnieuw, want de site is misschien nog niet geprovisioneerd
        }
    }
    
    Disconnect-SPOService # Verbreek SPO Service verbinding

    if (-not $siteValidated) {
        throw "De SharePoint site voor groep '$algemeenGroupName' met de gewenste URL is niet geprovisioneerd binnen de verwachte tijd. Script afgebroken."
    }
    Write-Host "SharePoint site voor '$algemeenGroupName' met de juiste URL is klaar." -ForegroundColor Green

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

} # Einde van het hoofd Try-blok
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
    Write-Host "`nScript voltooid." -ForegroundColor DarkCyan
}