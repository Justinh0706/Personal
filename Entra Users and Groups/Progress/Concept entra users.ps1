  <#
.Omschrijving
Script om een standaard Microsoft 365 omgeving in te richten
Dit script is bewust eenvoudig geschreven, zodat hij ook makkelijk aan te passen is voor iemand met alleen basiskennis van Powershell (wat overigens ook mijn eigen niveau is)
Verwijder na het aanmaken de gebruikers die niet van toepassing zijn uit Entra

LET OP - BELANGRIJKE INFORMATIE: 
Controleer altijd na het uitvoeren van dit script of de configuratie overeenkomt met de handleiding. 
Met name toewijzingen van licenties, gebruikers en groepen zijn belangrijk om te controleren omdat niets zo veranderlijk is als Microsoft 365 en Azure
 
Dit script gebruikt op dit moment (29-01-2024) de AzureADPreview module omdat alleen die ondersteuning biedt voor o.a. dynamische groepen in Entra.
Het script verwijdert daarom eerst de AzureAD module en installeert vervolgens AzureADPreview. Dit zal later nog wijzigen als AzureADPreview gereleased is
#>

Set-ExecutionPolicy bypass

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

#Deze URL wordt gebruikt om connectie te maken met het Sharepoint Admin center
$adminUrl = "https://deeznutsnl-admin.sharepoint.com"

#Hier wordt de URL omgezet
$oldUrl = "https://deeznutsnl.sharepoint.com/sites/algemeen"
$newUrl = "https://deeznutsnl.sharepoint.com/sites/willbedeleted"


# Hieronder installeren we de benodigde modules voor dit script. Voel je vrij om deze uit te schakelen (#) als je zeker weet dat je deze modules al hebt.


# AzureAD verwijderen en AzureADPreview installeren of updaten

#Uninstall-Module -Name AzureAD
#uninstall-Module -name AzureADPreview

#Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
#Install-Module Microsoft.Graph -Scope CurrentUser -Force

#Import-Module -Name Microsoft.online.sharepoint.PowerShell
#Import-module Microsoft.Graph.Authentication
#Import-module Microsoft.graph.Users

####################################################### Hieronder niets aanpassen ##########################################################################

# Connect met SharePoint Online Admin Center
Connect-SPOService -Url $adminUrl

Start-SPOSiteRename -Identity $oldUrl -NewSiteUrl $newUrl

Disconnect-SPOService

# Verbinden met AzureAD

Connect-MgGraph -scopes "Group.ReadWrite.All", "Directory.ReadWrite.All"


# Standaard lijst met accounts aanmaken.


# Behandelkamers
New-MgUser -DisplayName "Behandelkamer1" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer1" `
-UserPrincipalName "Behandelkamer1@$domainname" 

New-MgUser -DisplayName "Behandelkamer2" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer2" `
-UserPrincipalName "Behandelkamer2@$domainname" 

New-MgUser -DisplayName "Behandelkamer3" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer3" `
-UserPrincipalName "Behandelkamer3@$domainname" 

New-MgUser -DisplayName "Behandelkamer4" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer4" `
-UserPrincipalName "Behandelkamer4@$domainname"

New-MgUser -DisplayName "Behandelkamer5" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer5" `
-UserPrincipalName "Behandelkamer5@$domainname" 

New-MgUser -DisplayName "Behandelkamer6" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer6" `
-UserPrincipalName "Behandelkamer6@$domainname" 

New-MgUser -DisplayName "Behandelkamer7" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer7" `
-UserPrincipalName "Behandelkamer7@$domainname"

New-MgUser -DisplayName "Behandelkamer8" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Behandelkamer8" `
-UserPrincipalName "Behandelkamer8@$domainname"


#Balie

New-MgUser -DisplayName "Balie1" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Balie1" `
-UserPrincipalName "Balie1@$domainname"

New-MgUser -DisplayName "Balie2" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Balie2" `
-UserPrincipalName "Balie2@$domainname"

New-MgUser -DisplayName "Balie3" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Balie3" `
-UserPrincipalName "Balie3@$domainname" 

New-MgUser -DisplayName "Balie4" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Balie4" `
-UserPrincipalName "Balie4@$domainname"

#Backoffice

New-MgUser -DisplayName "Backoffice1" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Backoffice1" `
-UserPrincipalName "Backoffice1@$domainname" 

New-MgUser -DisplayName "Backoffice2" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Backoffice2" `
-UserPrincipalName "Backoffice2@$domainname"

#Kantoor

New-MgUser -DisplayName "Kantoor1" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Kantoor1" `
-UserPrincipalName "Kantoor1@$domainname"

New-MgUser -DisplayName "Kantoor2" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Kantoor2" `
-UserPrincipalName "Kantoor2@$domainname"

#Rontgen

New-MgUser -DisplayName "Rontgen1" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Rontgen1" `
-UserPrincipalName "Rontgen1@$domainname"

#Sterilisatie

New-MgUser -DisplayName "Sterilisatie1" -PasswordProfile $PasswordProfile `
-AccountEnabled:$true -MailNickName "Sterilisatie1" `
-UserPrincipalName "Sterilisatie1@$domainname"




#Creatie van Persoonlijke users (Dit kan uitgeschakeld worden als dit niet nodig is door een # voor de string te zetten).


foreach ($user in $personal) {
    $displayName = "$($user.Voornaam) $($user.Achternaam)"
    $userPrincipalName = "$($user.Voorletter).$($user.Achternaam)@deeznutz.nl"
    $mailNickname = "$($user.Voornaam)"

        # Hier komt je user creatie commando, bijvoorbeeld:
    New-MgUser `
        -DisplayName $displayName `
        -GivenName $user.Voornaam `
        -Surname $user.Achternaam `
        -PasswordProfile $PasswordProfile `
        -MailNickName $mailNickname `
        -UserPrincipalName $userPrincipalName `
        -AccountEnabled:$true `

}




#Aanmaken van Security groups
New-MgGroup -DisplayName Users-Email -MailEnabled:$false -MailNickName Users-Email -SecurityEnabled:$true
New-MgGroup -DisplayName Users-RDPEnabled -MailEnabled:$false -MailNickName Users-RDPEnabled -SecurityEnabled:$true




#Aanmaken Dynamische User groepen

New-MgGroup -DisplayName "Users-AllUsers" -Description "Alle Users" -MailEnabled:$false -MailNickname "AllUsers" -SecurityEnabled:$true
New-MgGroup -DisplayName "Users-Shared" -Description "Shared Users" -MailEnabled:$false -MailNickname "SharedUsers" -SecurityEnabled:$true 
New-MgGroup -DisplayName "Users-Personal" -Description "Users Personal" -MailEnabled:$false -MailNickname "PersonalUsers" -SecurityEnabled:$true 
New-MgGroup -DisplayName "Application-Microsoft365" -Description "Microsoft 365 App" -MailEnabled:$false -MailNickname "MicrosoftApp" -SecurityEnabled:$true

#Dynamische Device groepen
New-MgGroup -displayname "Devices-EntraJoined" -Description "Entra joined devices" -MailEnabled:$false -MailNickname "Entrajoined" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.deviceTrustType -eq "AzureAD") -or (device.deviceTrustType -eq "ServerAD")' -MembershipRuleProcessingState "On"
New-MgGroup -displayname "Devices-Autopilot" -Description "Autopilot joined devices" -MailEnabled:$false -MailNickname "Autopilotjoined" -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule '(device.devicePhysicalIDs -any _ -contains "[ZTDId]")' -MembershipRuleProcessingState "On"



#Licentie Groepen
New-MgGroup -DisplayName "License-BusinessPremium" -Description "Groep om Business Premium toe te wijzen aan gebruikers" -MailEnabled:$false -MailNickname "BPremium" -SecurityEnabled:$true 
New-MgGroup -DisplayName "License-ExchangeOnline" -Description "Groep om Exchange Online toe te wijzen aan gebruikers" -MailEnabled:$false -MailNickname "Exchange" -SecurityEnabled:$true 



#Aanmaken Management Schijf

New-MgGroup -DisplayName "Management" -Description "Management" -MailEnabled:$True -SecurityEnabled:$True -MailNickname Management -GroupTypes "Unified" -MembershipRuleProcessingState "On"



#Groepen toevoegen aan licenties

Start-Sleep -Seconds 30  # wacht even na het aanmaken van groepen

$OutputYN = Read-Host "Voeg nu eerst handmatig een Business Premium licentie toe aan een gebruiker, Voer Y in wanneer dit gelukt is (Y/N)"
If (“y”,”n” -notcontains $OutputYN) {
    Do {
    $OutputYN = Read-Host "Please input either a 'Y' for yes or a 'N' for no"
    } While (“y”,”n” -notcontains $OutputYN)
}
if ($OutputYN -eq "Y") { 
        $OutputLoc = $startDirectory
}
elseif ($OutputYN -eq "N") {
    $OutputLocDir = New-Object System.Windows.Forms.FolderBrowserDialog
    $OutputLocDir.Description = "Select a folder for the output"
    $OutputLocDir.SelectedPath = "$StartDirectory"
    if ($OutputLocDir.ShowDialog() -eq "OK") {
        $OutputLoc = $OutputLocDir.SelectedPath
        $OutputLoc = $OutputLoc.TrimEnd('\')
    }
}  

################### Business Premium ##########################

$targetGroupName = "License-BusinessPremium" # De statische weergavenaam van de groep waaraan de licentie moet worden toegewezen
$businessPremiumLicenseDisplayName = "Microsoft 365 Business Premium" # Naam voor display, niet voor lookup

# --- Script Start ---

try {
    

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


Start-Sleep 30

##### Bewerken Algemeen schijf ############

# De naam van de groep die je wilt verwijderen
$groupName = "Algemeen"

$group = Get-MgGroup -Filter "displayName eq '$groupName'"

if ($group) {
    # Verwijder de groep op basis van het Id
    Remove-MgGroup -GroupId $group.Id -Confirm:$false
    Write-Output "Groep '$groupName' is verwijderd."
} else {
    Write-Output "Groep '$groupName' niet gevonden."

    }


Start-sleep 10

New-MgGroup -DisplayName "Algemeen" -Description "Algemeen" -MailEnabled:$True -SecurityEnabled:$True -MailNickname Algemeen -GroupTypes "DynamicMembership", "Unified" -MembershipRule '(user.objectId -ne null) and (user.userType -eq "Member")' -MembershipRuleProcessingState "On"

Start-sleep 15

##### Hier word een owner toegevoegd aan de algemeen groep zodat Teams geactiveerd kan worden.


$businessPremiumLicenseDisplayName = "Microsoft 365 Business Premium"
$groupNameToSearch = "Algemeen" # De statische weergavenaam van de groep


try {
 

    # Stap 2: Vraag om de groepseigenaar en valideer deze in een lus
    $validOwner = $null
    $businessPremiumSkuIdToUse = $null # Deze variabele zal de geselecteerde SkuId bevatten

    while ($null -eq $validOwner) {
        Write-Host "`nStap 2: Groepseigenaar selecteren en licentie valideren." -ForegroundColor Yellow
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
            Write-Warning "✗ Gebruiker '$($potentialOwner.DisplayName)' is niet actief (geblokkeerd). Kies een actieve gebruiker."
            continue
        }

        # Validatie 2: Toon de licenties en vraag om de juiste SkuId te selecteren
        $assignedSkuIds = $null
        if ($null -ne $potentialOwner.AssignedLicenses -and $potentialOwner.AssignedLicenses.Count -gt 0) {
            $assignedSkuIds = $potentialOwner.AssignedLicenses | Select-Object -ExpandProperty SkuId
            Write-Host "`nDe volgende SkuId's zijn toegewezen aan '$($potentialOwner.DisplayName)':" -ForegroundColor Cyan
            $assignedSkuIds | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
        } else {
            Write-Warning "Gebruiker '$($potentialOwner.DisplayName)' heeft geen direct toegewezen licenties. Kies een andere gebruiker."
            continue
        }
        
        # Vraag de gebruiker om de correcte SkuId te selecteren/bevestigen
        $selectedSkuId = Read-Host "`nKopieer en plak de exacte SkuId hierboven die overeenkomt met '$businessPremiumLicenseDisplayName'"
        
        # Valideer of de ingevoerde SkuId daadwerkelijk bij de potentiele eigenaar hoort
        if ($assignedSkuIds -contains $selectedSkuId) {
            $businessPremiumSkuIdToUse = $selectedSkuId 
            Write-Host "✓ De licentie (SkuId: $selectedSkuId) is geselecteerd voor controle." -ForegroundColor Green
            $validOwner = $potentialOwner # Gebruiker en SkuId zijn nu gevalideerd
        } else {
            Write-Warning "De ingevoerde SkuId '$selectedSkuId' is NIET gevonden bij de opgegeven gebruiker '$($potentialOwner.DisplayName)'. Probeer het opnieuw."
            # Blijft in de lus, vraagt om nieuwe gebruiker
        }
    }

    # Stap 3: Zoek de Microsoft 365-groep met de statische naam "Algemeen"
    Write-Host "`nStap 3: Zoeken naar de groep '$groupNameToSearch'..." -ForegroundColor Yellow
    $targetGroup = Get-MgGroup -Filter "displayName eq '$groupNameToSearch'"
    
    if (-not $targetGroup) {
        throw "De groep met de naam '$groupNameToSearch' kon niet worden gevonden."
    }
    if ($targetGroup.Count -gt 1) {
        throw "Meerdere groepen gevonden met de naam '$groupNameToSearch'. Wees specifieker of gebruik een unieke naam."
    }
    Write-Host "✓ Groep gevonden: $($targetGroup.DisplayName) (ID: $($targetGroup.Id))" -ForegroundColor Green

    # Stap 4: Controleer of de gebruiker al eigenaar is en voeg toe indien nodig
    Write-Host "`nStap 4: Controleren en toevoegen van eigenaar..." -ForegroundColor Yellow
    $currentOwners = Get-MgGroupOwner -GroupId $targetGroup.Id
    
    if ($validOwner.Id -in $currentOwners.Id) {
        Write-Host "$($validOwner.DisplayName) is al eigenaar van de groep '$($targetGroup.DisplayName)'." -ForegroundColor Cyan
        Write-Host "Script is voltooid, geen wijzigingen nodig."
    }
    else {
        New-MgGroupOwner -GroupId $targetGroup.Id -DirectoryObjectId $validOwner.Id
        Write-Host "✓ SUCCES! '$($validOwner.DisplayName)' is nu eigenaar van de groep '$($targetGroup.DisplayName)'." -ForegroundColor Green
        Write-Host "De groep is nu klaar om er een Microsoft Team van te maken."
    }
}
catch {
    Write-Error "Er is een fout opgetreden: $($_.Exception.Message)"
}


Start-sleep 10

####Teams Activeren####

$teamsGroup = Get-MgGroup -Filter "displayName eq 'Algemeen'" | Select-Object -First 1

if ($teamsGroup) {
    try {
        # Teams activeren op de bestaande Microsoft 365 groep
        New-MgTeam -GroupId $teamsGroup.Id `
            -MemberSettings @{ AllowCreateUpdateChannels = $true } `
            -MessagingSettings @{ AllowUserEditMessages = $true } `
            -FunSettings @{ AllowGiphy = $true }

        Write-Host "✅ Teams succesvol geactiveerd voor groep '$($teamsGroup.DisplayName)'"
    } catch {
        Write-Host "❌ Fout bij activeren van Teams:"
        Write-Host $_.Exception.Message
    }
} else {
    Write-Host "❌ Groep 'Algemeen' niet gevonden."
}

