<#
.Omschrijving
Script om een standaard Microsoft 365 omgeving in te richten.
Dit script is geoptimaliseerd voor leesbaarheid, onderhoud en modern gebruik van de Microsoft Graph PowerShell module.

Auteur: Matthijs Aarnoudse & Justin de Haas

LET OP - BELANGRIJKE INFORMATIE: 
Controleer altijd na het uitvoeren van dit script of de configuratie overeenkomt met de handleiding. 
Microsoft 365 en Entra ID zijn constant in ontwikkeling. Controleer met name licentie-, gebruiker- en groepstoewijzingen.

Dit script gebruikt de Microsoft.Graph module, de opvolger van de AzureAD en AzureADPreview modules.
#>

#================================================================================
# CONFIGURATIE - Pas de onderstaande waardes aan voor dit project
#================================================================================

# Vul hier het primaire domein van de tenant in (bijv. praktijkbeukenlaan.nl)
$domainname = "deeznutz.nl"

# Standaard wachtwoordprofiel voor alle nieuwe gebruikers.
$PasswordProfile = @{
    Password                       = 'WerkplekWachtwoord123!' 
    ForceChangePasswordNextSignIn        = $false
    ForceChangePasswordNextSignInWithMfa = $true
}

# Lijst van persoonlijke gebruikers die aangemaakt moeten worden.
$personalUsers = @(
    @{ Voorletter = "J"; Voornaam = "Jan"; Achternaam = "Hans" },
    @{ Voorletter = "A"; Voornaam = "Pieter"; Achternaam = "Jansen" }
)

# Lijsten van generieke/gedeelde gebruikers die aangemaakt moeten worden.
$behandelkamerUsers = 1..8 | ForEach-Object { "Behandelkamer$_" }
$balieUsers = 1..4 | ForEach-Object { "Balie$_" }
$backofficeUsers = 1..2 | ForEach-Object { "Backoffice$_" }
$kantoorUsers = 1..2 | ForEach-Object { "Kantoor$_" }
$rontgenUsers = 1..1 | ForEach-Object { "Rontgen$_" }
$sterilisatieUsers = 1..1 | ForEach-Object { "Sterilisatie$_" }

$allGenericUsers = $behandelkamerUsers + $balieUsers + $backofficeUsers + $kantoorUsers + $rontgenUsers + $sterilisatieUsers

#================================================================================
# SCRIPT START - Hieronder in principe niets aanpassen
#================================================================================

# --- Stap 1: Voorbereiding en Verbinding ---
Write-Host "Stap 1: Voorbereiding en verbinding met Microsoft Graph..." -ForegroundColor Yellow

try {
    Import-Module Microsoft.Graph.Groups, Microsoft.Graph.Teams, Microsoft.Graph.Users
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All", "User.ReadWrite.All", "Team.Create", "GroupMember.ReadWrite.All", "TeamSettings.ReadWrite.All", "Directory.AccessAsUser.All"
    Write-Host "✅ Succesvol verbonden met Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Host "❌ Fout bij het verbinden of importeren van modules. Controleer of de Microsoft.Graph module correct is geïnstalleerd." -ForegroundColor Red
    Write-Error $_
    exit
}

# --- Stap 2: Gebruikers aanmaken ---
Write-Host "`nStap 2: Gebruikers aanmaken..." -ForegroundColor Yellow

foreach ($userName in $allGenericUsers) {
    if (Get-MgUser -Filter "userPrincipalName eq '$($userName)@$domainname'") { Write-Host "  - Gebruiker '$userName' bestaat al, wordt overgeslagen."; continue }
    try { New-MgUser -DisplayName $userName -UserPrincipalName "$($userName)@$domainname" -MailNickName $userName -AccountEnabled:$true -PasswordProfile $PasswordProfile; Write-Host "  ✅ Gebruiker '$userName' succesvol aangemaakt." }
    catch { Write-Host "  ❌ Fout bij aanmaken van gebruiker '$userName': $($_.Exception.Message)" -ForegroundColor Red }
}
foreach ($user in $personalUsers) {
    $displayName = "$($user.Voornaam) $($user.Achternaam)"; $userPrincipalName = "$($user.Voorletter).$($user.Achternaam)@$domainname"
    if (Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'") { Write-Host "  - Gebruiker '$displayName' bestaat al, wordt overgeslagen."; continue }
    $mailNickname = "$($user.Voornaam)$($user.Achternaam)" -replace '\s'
    try { New-MgUser -DisplayName $displayName -GivenName $user.Voornaam -Surname $user.Achternaam -UserPrincipalName $userPrincipalName -MailNickName $mailNickname -AccountEnabled:$true -PasswordProfile $PasswordProfile; Write-Host "  ✅ Persoonlijke gebruiker '$displayName' succesvol aangemaakt." }
    catch { Write-Host "  ❌ Fout bij aanmaken van gebruiker '$displayName': $($_.Exception.Message)" -ForegroundColor Red }
}

# --- Stap 3: Security en Dynamische Groepen aanmaken ---
Write-Host "`nStap 3: Security en Dynamische Groepen aanmaken..." -ForegroundColor Yellow

$genericUserFilter = "Behandelkamer|Balie|Backoffice|Kantoor|Rontgen|Sterilisatie"
$groupDefinitions = @(
    @{ DisplayName = "Users-Email"; MailEnabled = $false; MailNickName = "Users-Email"; SecurityEnabled = $true },
    @{ DisplayName = "Users-RDPEnabled"; MailEnabled = $false; MailNickName = "Users-RDPEnabled"; SecurityEnabled = $true },
    @{ DisplayName = "Users-AllUsers"; Description = "Alle gebruikers in de tenant"; MailEnabled = $false; MailNickname = "AllUsers"; SecurityEnabled = $true; GroupTypes = @("DynamicMembership"); MembershipRule = '(user.objectId -ne null)'; MembershipRuleProcessingState = "On" },
    @{ DisplayName = "Users-Shared"; Description = "Alle generieke/gedeelde gebruikers"; MailEnabled = $false; MailNickname = "SharedUsers"; SecurityEnabled = $true; GroupTypes = @("DynamicMembership"); MembershipRule = "(user.displayName -match ""$genericUserFilter"")"; MembershipRuleProcessingState = "On" },
    @{ DisplayName = "Users-Personal"; Description = "Alle persoonlijke gebruikers"; MailEnabled = $false; MailNickname = "PersonalUsers"; SecurityEnabled = $true; GroupTypes = @("DynamicMembership"); MembershipRule = "(user.displayName -notMatch ""$genericUserFilter"")"; MembershipRuleProcessingState = "On" },
    @{ DisplayName = "Application-Microsoft365"; Description = "Microsoft 365 App"; MailEnabled = $false; MailNickname = "MicrosoftApp"; SecurityEnabled = $true },
    @{ DisplayName = "Devices-EntraJoined"; Description = "Alle Entra joined devices"; MailEnabled = $false; MailNickname = "Entrajoined"; SecurityEnabled = $true; GroupTypes = @("DynamicMembership"); MembershipRule = '(device.deviceTrustType -eq "AzureAD")'; MembershipRuleProcessingState = "On" },
    @{ DisplayName = "Devices-Autopilot"; Description = "Alle Windows Autopilot devices"; MailEnabled = $false; MailNickname = "Autopilotjoined"; SecurityEnabled = $true; GroupTypes = @("DynamicMembership"); MembershipRule = '(device.devicePhysicalIDs -any (_ -contains "[ZTDId]"))'; MembershipRuleProcessingState = "On" },
    @{ DisplayName = "License-BusinessPremium"; Description = "Groep om Business Premium toe te wijzen"; MailEnabled = $false; MailNickname = "BPremium"; SecurityEnabled = $true },
    @{ DisplayName = "License-ExchangeOnline"; Description = "Groep om Exchange Online toe te wijzen"; MailEnabled = $false; MailNickname = "Exchange"; SecurityEnabled = $true }
)
foreach ($groupDef in $groupDefinitions) {
    if (-not (Get-MgGroup -Filter "displayName eq '$($groupDef.DisplayName)'")) { New-MgGroup @groupDef; Write-Host "  ✅ Groep '$($groupDef.DisplayName)' aangemaakt." } 
    else { Write-Host "  - Groep '$($groupDef.DisplayName)' bestaat al, wordt overgeslagen." }
}

# --- Stap 4: Microsoft 365 Groepen en Teams aanmaken/configureren ---
Write-Host "`nStap 4: Microsoft 365 Groepen en Teams configureren..." -ForegroundColor Yellow
function New-UnifiedGroupAndTeam {
    param ([string]$DisplayName, [string]$MailNickname, [string]$Description, [bool]$IsDynamic = $false, [string]$MembershipRule)
    Write-Host "Bezig met groep en team '$DisplayName'..."
    $existingGroup = Get-MgGroup -Filter "displayName eq '$DisplayName'"; if ($existingGroup) { Write-Host "  - Bestaande groep '$DisplayName' gevonden, wordt verwijderd."; Remove-MgGroup -GroupId $existingGroup.Id; Start-Sleep -Seconds 5 }
    $groupParams = @{ DisplayName = $DisplayName; Description = $Description; MailEnabled = $true; SecurityEnabled = $true; MailNickname = $MailNickname; GroupTypes = @("Unified") }
    if ($IsDynamic) { $groupParams.GroupTypes += "DynamicMembership"; $groupParams.Add("MembershipRule", $MembershipRule); $groupParams.Add("MembershipRuleProcessingState", "On") }
    try {
        $newGroup = New-MgGroup @groupParams; Write-Host "  ✅ M365-groep '$($newGroup.DisplayName)' (ID: $($newGroup.Id)) aangemaakt."
        Write-Host "  - Wacht 15 seconden voor replicatie..."; Start-Sleep -Seconds 15
        $teamBody = @{ "template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"; "group@odata.bind" = "https://graph.microsoft.com/v1.0/groups('$($newGroup.Id)')" }
        New-MgTeam -BodyParameter $teamBody; Write-Host "  ✅ Teams succesvol geactiveerd voor groep '$($newGroup.DisplayName)'."
    } catch { Write-Host "  ❌ Fout bij verwerken van groep '$DisplayName': $($_.Exception.Message)" -ForegroundColor Red }
}
New-UnifiedGroupAndTeam -DisplayName "Algemeen" -MailNickname "Algemeen" -Description "Algemeen team voor alle medewerkers" -IsDynamic $true -MembershipRule '(user.userType -eq "Member")'
New-UnifiedGroupAndTeam -DisplayName "Management" -MailNickname "Management" -Description "Team voor het management"


# --- Stap 5: Licenties toewijzen aan groepen ---
Write-Host "`nStap 5: Licenties toewijzen aan groepen..." -ForegroundColor Yellow
Write-Host "Wacht 30 seconden om Entra ID de tijd te geven de groepen te verwerken..."
Start-Sleep -Seconds 30

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

Write-Host "`nScript voltooid! Controleer de Entra ID en Teams portals voor de resultaten." -ForegroundColor Cyan