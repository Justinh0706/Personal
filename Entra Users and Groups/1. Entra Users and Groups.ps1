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

Set-ExecutionPolicy Bypass

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

Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
Install-Module Microsoft.Graph -Scope CurrentUser -Force

Import-Module -Name Microsoft.online.sharepoint.PowerShell
Import-module Microsoft.Graph.Authentication
Import-module Microsoft.graph.Users

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

################### Business Premium ##########################

$groepNaam1 = "License-BusinessPremium"
$licentieNaam1 = "BUSINESS_PREMIUM"

$groep1 = Get-MgGroup -Filter "displayName eq '$groepNaam1'" | Select-Object -First 1

if (-not $groep1) {
    Write-Host "❌ Groep '$groepNaam1' niet gevonden."
} else {
    Write-Host "✅ Groep gevonden: $($groep1.DisplayName) (ID: $($groep1.Id))"

    $sku1 = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $licentieNaam1 }

    if (-not $sku1) {
        Write-Host "❌ Licentie '$licentieNaam1' niet gevonden."
    } else {
        Write-Host "✅ Licentie gevonden: $($sku1.SkuPartNumber) (SkuId: $($sku1.SkuId))"

        try {
            Set-MgGroupLicense -GroupId $groep1.Id `
                               -AddLicenses @{ SkuId = $sku1.SkuId } `
                               -RemoveLicenses @()
            Write-Host "✅ Licentie '$licentieNaam1' succesvol toegewezen aan groep '$groepNaam1'."
        } catch {
            Write-Host "❌ Fout bij toewijzen licentie '$licentieNaam1': $_"
        }
    }
}


################### Exchange Online ##########################

$groepNaam2 = "License-ExchangeOnline"
$licentieNaam2 = "EXCHANGE_S_STANDARD"

$groep2 = Get-MgGroup -Filter "displayName eq '$groepNaam2'" | Select-Object -First 1

if (-not $groep2) {
    Write-Host "❌ Groep '$groepNaam2' niet gevonden."
} else {
    Write-Host "✅ Groep gevonden: $($groep2.DisplayName) (ID: $($groep2.Id))"

    $sku2 = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $licentieNaam2 }

    if (-not $sku2) {
        Write-Host "❌ Licentie '$licentieNaam2' niet gevonden."
    } else {
        Write-Host "✅ Licentie gevonden: $($sku2.SkuPartNumber) (SkuId: $($sku2.SkuId))"

        try {
            Set-MgGroupLicense -GroupId $groep2.Id `
                               -AddLicenses @{ SkuId = $sku2.SkuId } `
                               -RemoveLicenses @()
            Write-Host "✅ Licentie '$licentieNaam2' succesvol toegewezen aan groep '$groepNaam2'."
        } catch {
            Write-Host "❌ Fout bij toewijzen licentie '$licentieNaam2': $_"
        }
    }
}

Start-Sleep 30

#Bewerken Algemeen schijf

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

New-MgGroup -DisplayName "Algemeen" -Description "Algemeen" -MailEnabled:$True -SecurityEnabled:$True -MailNickname Algemeen -GroupTypes "DynamicMembership", "Unified" -MembershipRule '(user.objectId -ne null) and (user.userType -eq "Member")' -MembershipRuleProcessingState "On"


# Stap 1: Zoek de Business Premium licentie
$bpSku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq "BUSINESS_PREMIUM" }

if (-not $bpSku) {
    Write-Host "❌ Business Premium licentie niet gevonden." -ForegroundColor Red
    return
}

$bpSkuId = $bpSku.SkuId

# Stap 2: Zoek een gebruiker met die licentie
$userWithBp = Get-MgUser -All | Where-Object {
    $_.AssignedLicenses.SkuId -contains $bpSkuId
} | Select-Object -First 1

if (-not $userWithBp) {
    Write-Host "❌ Geen gebruiker gevonden met Business Premium licentie." -ForegroundColor Red
    return
}

Write-Host "✅ Gebruiker gevonden: $($userWithBp.DisplayName) ($($userWithBp.UserPrincipalName))" -ForegroundColor Green

# Stap 3: Zoek de groep 'Algemeen'
$group = Get-MgGroup -Filter "displayName eq 'Algemeen'" | Select-Object -First 1

if (-not $group) {
    Write-Host "❌ Groep 'Algemeen' niet gevonden." -ForegroundColor Red
    return
}

# Stap 4: Voeg de gebruiker toe als owner van de groep
try {
    Add-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($userWithBp.Id)"
    }

    Write-Host "✅ Gebruiker succesvol toegevoegd als owner aan groep 'Algemeen'" -ForegroundColor Green
}
catch {
    Write-Host "❌ Fout bij toevoegen als owner:" -ForegroundColor Red
    Write-Host $_.Exception.Message
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

