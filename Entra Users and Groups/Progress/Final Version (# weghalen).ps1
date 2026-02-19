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

Set-ExecutionPolicy -scope CurrentUser Bypass

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

# --- Hoofd Try-Catch-Finally blok voor het hele script (voor robuuste foutafhandeling en verbindingen) ---
try {
    # --- Stap 1: Voorbereiding en Verbinding ---
    Write-Host "Stap 1: Voorbereiding en verbinding met Microsoft Graph..." -ForegroundColor Yellow

    # Installeer de modules als je dat nog niet gedaan hebt (verwijder de # voor de regels)
    # Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
    # Install-Module Microsoft.Graph.Groups -Scope CurrentUser -Force -AllowClobber
    # Install-Module Microsoft.Graph.Teams -Scope CurrentUser -Force -AllowClobber
    # Install-Module Microsoft.Graph.Users -Scope CurrentUser -Force -AllowClobber
    # Install-Module Microsoft.Graph.DirectoryObjects -Scope CurrentUser -Force -AllowClobber # Voor het verwijderen van deleted items indien nodig

    Import-Module Microsoft.Graph.Groups, Microsoft.Graph.Teams, Microsoft.Graph.Users, Microsoft.Graph.Authentication, Microsoft.Graph.DirectoryObjects -ErrorAction Stop
    
    # Zorg ervoor dat alle benodigde scopes aanwezig zijn voor groepen, gebruikers en teams
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All", "User.ReadWrite.All", "Team.Create", "GroupMember.ReadWrite.All", "TeamSettings.ReadWrite.All", "Directory.AccessAsUser.All", "Domain.Read.All", "Organization.Read.All" -ErrorAction Stop
    Write-Host "Succesvol verbonden met Microsoft Graph." -ForegroundColor Green


    # --- Stap 2: Gebruikers aanmaken ---
    Write-Host "`nStap 2: Gebruikers aanmaken..." -ForegroundColor Yellow

    foreach ($userName in $allGenericUsers) {
        # -ErrorAction SilentlyContinue voorkomt dat de script stopt als gebruiker niet gevonden wordt
        if (Get-MgUser -Filter "userPrincipalName eq '$($userName)@$domainname'" -ErrorAction SilentlyContinue) { Write-Host "  - Gebruiker '$userName@$domainname' bestaat al, wordt overgeslagen."; continue }
        try { 
            New-MgUser -DisplayName $userName -UserPrincipalName "$($userName)@$domainname" -MailNickName $userName -AccountEnabled:$true -PasswordProfile $PasswordProfile -ErrorAction Stop
            Write-Host "  Gebruiker '$userName@$domainname' succesvol aangemaakt." -ForegroundColor Green 
        }
        catch { 
            Write-Host "  Fout bij aanmaken van gebruiker '$userName@$domainname': $($_.Exception.Message)" -ForegroundColor Red 
        }
    }
    foreach ($user in $personalUsers) {
        $displayName = "$($user.Voornaam) $($user.Achternaam)"; $userPrincipalName = "$($user.Voorletter).$($user.Achternaam)@$domainname"
        if (Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'" -ErrorAction SilentlyContinue) { Write-Host "  - Gebruiker '$displayName' bestaat al, wordt overgeslagen."; continue }
        $mailNickname = "$($user.Voornaam)$($user.Achternaam)" -replace '\s' # Verwijder spaties uit mailnickname
        try { 
            New-MgUser -DisplayName $displayName -GivenName $user.Voornaam -Surname $user.Achternaam -UserPrincipalName $userPrincipalName -MailNickName $mailNickname -AccountEnabled:$true -PasswordProfile $PasswordProfile -ErrorAction Stop
            Write-Host "  Persoonlijke gebruiker '$displayName' succesvol aangemaakt." -ForegroundColor Green 
        }
        catch { 
            Write-Host "  Fout bij aanmaken van gebruiker '$displayName': $($_.Exception.Message)" -ForegroundColor Red 
        }
    }

    # --- Stap 3: Security en Dynamische Groepen aanmaken/synchroniseren ---
    Write-Host "`nStap 3: Security en Dynamische Groepen aanmaken/synchroniseren..." -ForegroundColor Yellow

    $genericUserFilter = "Behandelkamer|Balie|Backoffice|Kantoor|Rontgen|Sterilisatie" # Gebruikt voor de Shared/Personal dynamic groups
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
        @{ DisplayName = "License-ExchangeOnline"; Description = "Groep om Exchange Online toe te wijzijgen"; MailEnabled = $false; MailNickname = "Exchange"; SecurityEnabled = $true }
    )

    foreach ($groupDef in $groupDefinitions) {
        $existingGroup = Get-MgGroup -Filter "displayName eq '$($groupDef.DisplayName)'" -ErrorAction SilentlyContinue
        if (-not $existingGroup) { 
            try {
                New-MgGroup @groupDef -ErrorAction Stop; Write-Host "  Groep '$($groupDef.DisplayName)' succesvol aangemaakt." -ForegroundColor Green
            } catch {
                Write-Host "  Fout bij aanmaken van groep '$($groupDef.DisplayName)': $($_.Exception.Message)" -ForegroundColor Red
            }
        } else { 
            # Indien de groep al bestaat, controleer of het een dynamische groep moet zijn en update deze.
            Write-Host "  - Groep '$($groupDef.DisplayName)' bestaat al." -ForegroundColor DarkCyan
            $updateNeeded = $false
            $updatedProperties = @{ }

            # Bepaal de gewenste GroupTypes (voor security groepen is dit @() of @("DynamicMembership"))
            $desiredGroupTypes = @()
            if ($groupDef.GroupTypes -and $groupDef.GroupTypes -contains "DynamicMembership") {
                $desiredGroupTypes += "DynamicMembership"
            }
            $desiredGroupTypes = $desiredGroupTypes | Sort-Object | Select-Object -Unique # Sorteren en uniek maken voor vergelijking

            $currentGroupTypesSorted = $existingGroup.GroupTypes | Sort-Object | Select-Object -Unique

            # Vergelijk de GroupTypes
            if (-not ($currentGroupTypesSorted -join ',') -eq ($desiredGroupTypes -join ',')) {
                $updateNeeded = $true
                $updatedProperties.Add("GroupTypes", $desiredGroupTypes) # Correcte syntax voor het toevoegen van een array
                Write-Host "    - GroupTypes moeten worden bijgewerkt ($($currentGroupTypesSorted -join ', ') -> $($desiredGroupTypes -join ', '))." -ForegroundColor DarkCyan
            }

            # Controleer MembershipRule en ProcessingState indien dynamisch
            $isDesiredDynamic = $desiredGroupTypes -contains "DynamicMembership"
            $isCurrentDynamic = $currentGroupTypesSorted -contains "DynamicMembership"

            if ($isDesiredDynamic) {
                if ($existingGroup.MembershipRule -ne $groupDef.MembershipRule -or $existingGroup.MembershipRuleProcessingState -ne "On") {
                    $updateNeeded = $true
                    $updatedProperties.Add("MembershipRule", $groupDef.MembershipRule)
                    $updatedProperties.Add("MembershipRuleProcessingState", "On")
                    Write-Host "    - Lidmaatschapsregel of verwerkingsstatus moet worden bijgewerkt." -ForegroundColor DarkCyan
                }
            } elseif ($isCurrentDynamic) {
                # Als het statisch moet worden, maar nu dynamisch is
                $updateNeeded = $true
                $updatedProperties.Add("MembershipRule", $null)
                $updatedProperties.Add("MembershipRuleProcessingState", "None")
                Write-Host "    - Groep wordt omgezet naar statisch." -ForegroundColor DarkCyan
            }
            
            # Controleer Description
            if ($groupDef.Description -and $existingGroup.Description -ne $groupDef.Description) {
                $updatedProperties.Add("Description", $groupDef.Description)
                $updateNeeded = $true
                Write-Host "    - Beschrijving moet worden bijgewerkt." -ForegroundColor DarkCyan
            }

            # MailNickname en MailEnabled (voor Security groups zijn deze meestal false/niet-aanwezig)
            if ($groupDef.MailEnabled -ne $existingGroup.MailEnabled) {
                $updatedProperties.Add("MailEnabled", $groupDef.MailEnabled)
                $updateNeeded = $true
                Write-Host "    - MailEnabled status moet worden bijgewerkt." -ForegroundColor DarkCyan
            }
            if ($groupDef.MailNickname -and $existingGroup.MailNickname -ne $groupDef.MailNickname) {
                $updatedProperties.Add("MailNickname", $groupDef.MailNickname)
                $updateNeeded = $true
                Write-Host "    - MailNickname moet worden bijgewerkt." -ForegroundColor DarkCyan
            }

            if ($updateNeeded) {
                try {
                    Update-MgGroup -GroupId $existingGroup.Id @updatedProperties -ErrorAction Stop
                    Write-Host "  Groep '$($groupDef.DisplayName)' succesvol bijgewerkt." -ForegroundColor Green
                } catch {
                    Write-Host "  Fout bij bijwerken van groep '$($groupDef.DisplayName)': $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  - Groep '$($groupDef.DisplayName)' is al correct geconfigureerd. Geen update nodig." -ForegroundColor DarkCyan
            }
        }
    }

    # --- Stap 4: Microsoft 365 Groepen en Teams aanmaken/configureren (Algemeen & Management) ---
    Write-Host "`nStap 4: Microsoft 365 Groepen en Teams configureren (Algemeen & Management)..." -ForegroundColor Yellow

    # Functie om Microsoft 365 Groepen (en optioneel Teams) aan te maken of te synchroniseren
    function Sync-UnifiedGroupAndTeam {
        param (
            [string]$DisplayName,
            [string]$MailNickname,
            [string]$Description,
            [bool]$IsDynamic = $false,
            [string]$MembershipRule, # Vereist indien $IsDynamic $true is
            [string]$OwnerUpn = $null, # Optionele parameter voor de UPN van de eigenaar
            [bool]$ActivateTeams = $true # NIEUW: Optionele parameter om Teams wel/niet te activeren
        )

        Write-Host "`nBezig met synchroniseren van groep en team '$DisplayName'..." -ForegroundColor Cyan

        $groupId = $null
        $existingGroup = Get-MgGroup -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue

        if ($existingGroup) {
            Write-Host "  - Bestaande groep '$DisplayName' (ID: $($existingGroup.Id)) gevonden. Controleren op update..." -ForegroundColor DarkCyan
            $groupId = $existingGroup.Id
            $updateNeeded = $false
            $updatedProperties = @{}
            
            # Bepaal de gewenste GroupTypes voor een Unified group
            $groupTypesToSet = @("Unified") 
            if ($IsDynamic) { $groupTypesToSet += "DynamicMembership" }
            $groupTypesToSet = $groupTypesToSet | Sort-Object | Select-Object -Unique # Sorteren en uniek maken voor vergelijking

            # Vergelijk de huidige GroupTypes met de gewenste
            $currentGroupTypesSorted = $existingGroup.GroupTypes | Sort-Object | Select-Object -Unique
            if (-not ($currentGroupTypesSorted -join ',') -eq ($groupTypesToSet -join ',')) {
                $updateNeeded = $true
                $updatedProperties.Add("GroupTypes", $groupTypesToSet)
                Write-Host "    - GroupTypes moeten worden bijgewerkt van '$($currentGroupTypesSorted -join ', ')' naar '$($groupTypesToSet -join ', ')'." -ForegroundColor DarkCyan
            }

            # Controleer MembershipRule en ProcessingState als dynamisch
            $currentMembershipRule = $existingGroup.MembershipRule
            $currentMembershipRuleProcessingState = $existingGroup.MembershipRuleProcessingState

            if ($IsDynamic) {
                # Check if current rule/state differs from desired
                if ($currentMembershipRule -ne $MembershipRule -or $currentMembershipRuleProcessingState -ne "On") {
                    $updateNeeded = $true
                    $updatedProperties.Add("MembershipRule", $MembershipRule)
                    $updatedProperties.Add("MembershipRuleProcessingState", "On")
                    Write-Host "    - Lidmaatschapsregel of verwerkingsstatus moet worden bijgewerkt." -ForegroundColor DarkCyan
                }
            } else { # If group should NOT be dynamic, but currently IS
                if ($currentGroupTypesSorted -contains "DynamicMembership") {
                    $updateNeeded = $true
                    Write-Host "    - Groep is onterecht dynamisch, wordt omgezet naar statisch." -ForegroundColor DarkCyan
                    # Verwijder DynamicMembership uit de types
                    $groupTypesToSet = $groupTypesToSet | Where-Object { $_ -ne "DynamicMembership" }
                    $updatedProperties["GroupTypes"] = $groupTypesToSet # Update de GroupTypes die gezet moeten worden
                    $updatedProperties.Add("MembershipRule", $null)
                    $updatedProperties.Add("MembershipRuleProcessingState", "None")
                }
            }

            # Check Description
            if ($existingGroup.Description -ne $Description) {
                $updateNeeded = $true
                $updatedProperties.Add("Description", $Description)
                Write-Host "    - Beschrijving moet worden bijgewerkt." -ForegroundColor DarkCyan
            }
            
            # MailNickname, DisplayName (voor M365 groups)
            if ($existingGroup.MailNickname -ne $MailNickname) {
                $updateNeeded = $true
                $updatedProperties.Add("MailNickname", $MailNickname)
                Write-Host "    - MailNickname moet worden bijgewerkt." -ForegroundColor DarkCyan
            }
            if ($existingGroup.DisplayName -ne $DisplayName) {
                $updateNeeded = $true
                $updatedProperties.Add("DisplayName", $DisplayName)
                Write-Host "    - DisplayName moet worden bijgewerkt." -ForegroundColor DarkCyan
            }
            # MailEnabled voor M365 groepen is altijd true, dus hoeven we niet te update.

            if ($updateNeeded) {
                try {
                    # Gebruik @updatedProperties voor de update
                    Update-MgGroup -GroupId $groupId @updatedProperties -ErrorAction Stop
                    Write-Host "  Groep '$DisplayName' succesvol bijgewerkt." -ForegroundColor Green
                    Start-Sleep -Seconds 10 # Geef tijd voor propagatie
                } catch {
                    Write-Host "  Fout bij bijwerken van groep '$DisplayName': $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  - Groep '$DisplayName' is al correct geconfigureerd. Geen update nodig." -ForegroundColor DarkCyan
            }

        } else { # Group does not exist, create it
            Write-Host "  - Groep '$DisplayName' niet gevonden. Nieuwe groep aanmaken..." -ForegroundColor Yellow
            $groupParams = @{ DisplayName = $DisplayName; Description = $Description; MailEnabled = $true; SecurityEnabled = $true; MailNickname = $MailNickname; GroupTypes = @("Unified") }
            if ($IsDynamic) { $groupParams.GroupTypes += "DynamicMembership"; $groupParams.Add("MembershipRule", $MembershipRule); $groupParams.Add("MembershipRuleProcessingState", "On") }

            try {
                $newGroup = New-MgGroup @groupParams -ErrorAction Stop
                $groupId = $newGroup.Id # Get ID for Teams creation
                Write-Host "  M365-groep '$($newGroup.DisplayName)' (ID: $($newGroup.Id)) succesvol aangemaakt." -ForegroundColor Green
                Start-Sleep -Seconds 15 # Geef tijd voor replicatie van de nieuwe groep
            } catch {
                Write-Host "  Fout bij aanmaken van groep '$DisplayName': $($_.Exception.Message)" -ForegroundColor Red
                return # Exit function if group creation failed
            }
        }

        # Owner Assignment (if OwnerUpn is provided)
        if (-not [string]::IsNullOrWhiteSpace($OwnerUpn)) {
            Write-Host "  - Bezig met toevoegen van eigenaar '$OwnerUpn' aan groep '$DisplayName'..." -ForegroundColor Cyan
            try {
                $ownerUserObject = Get-MgUser -UserId $OwnerUpn -Property "Id,DisplayName,AccountEnabled" -ErrorAction Stop
                $currentOwners = Get-MgGroupOwner -GroupId $groupId -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id

                if ($ownerUserObject.Id -in $currentOwners) {
                    Write-Host "  - '$($ownerUserObject.DisplayName)' is al eigenaar van groep '$DisplayName'. Overslaan." -ForegroundColor DarkCyan
                } else {
                    New-MgGroupOwner -GroupId $groupId -DirectoryObjectId $ownerUserObject.Id -ErrorAction Stop
                    Write-Host "  '$($ownerUserObject.DisplayName)' succesvol toegevoegd als eigenaar aan groep '$DisplayName'." -ForegroundColor Green
                    # Voeg een kleine vertraging toe voor eigenaarpropagatie voordat Teams wordt geactiveerd
                    Start-Sleep -Seconds 5
                }
            }
            catch {
                Write-Warning "  Fout bij toevoegen van eigenaar '$OwnerUpn' aan groep '$DisplayName': $($_.Exception.Message)"
                Write-Warning "  Zorg ervoor dat de eigenaar bestaat en de juiste licentie heeft voor Teams-functionaliteit."
            }
        }

        # Activate Teams (if group exists or was just created, we have a groupId, AND ActivateTeams is true)
        if ($groupId -and $ActivateTeams) { # AANPASSING HIER
            Write-Host "  - Controleren en activeren van Teams voor groep '$DisplayName'..." -ForegroundColor Cyan
            try {
                # Gebruik Get-MgGroupTeam om te controleren of een Team al aan de groep is gekoppeld
                $teamExistsForGroup = $null
                try {
                    $teamExistsForGroup = Get-MgGroupTeam -GroupId $groupId -ErrorAction Stop
                } catch {
                    # Als Get-MgGroupTeam faalt (bijv. omdat er geen team is), is $teamExistsForGroup $null
                }

                if ($teamExistsForGroup) {
                    Write-Host "  - Teams is al geactiveerd voor groep '$DisplayName'. Overslaan." -ForegroundColor DarkCyan
                } else {
                    $teamBody = @{ "template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"; "group@odata.bind" = "https://graph.microsoft.com/v1.0/groups('$groupId')" }
                    New-MgTeam -BodyParameter $teamBody -ErrorAction Stop
                    Write-Host "  Teams succesvol geactiveerd voor groep '$DisplayName'." -ForegroundColor Green
                }
            } catch {
                Write-Host "  Fout bij activeren van Teams voor groep '$DisplayName': $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "     Controleer of de groep voldoet aan de eisen voor Teams (o.a. een eigenaar met de juiste licentie en voldoende propagatietijd)." -ForegroundColor Red
            }
        } elseif ($groupId -and -not $ActivateTeams) { # NIEUW: Informatie als Teams NIET geactiveerd wordt
            Write-Host "  - Teams-activatie voor groep '$DisplayName' overgeslagen zoals gevraagd." -ForegroundColor DarkCyan
        }
    }

    # === Interactieve prompt voor Algemeen groep eigenaar ===
    $algemeenOwnerUpn = $null
    while ([string]::IsNullOrWhiteSpace($algemeenOwnerUpn)) {
        Write-Host "`nGeef de UPN (e-mailadres) op van de gebruiker die EIGENAAR moet worden van de 'Algemeen' groep." -ForegroundColor Yellow
        Write-Warning "Deze gebruiker MOET al een Microsoft 365 Business Premium licentie hebben, anders kan Teams niet geactiveerd worden voor de groep."
        $inputUpn = Read-Host "UPN van eigenaar voor 'Algemeen' groep"
        
        if ([string]::IsNullOrWhiteSpace($inputUpn)) {
            Write-Warning "Invoer is leeg. Geef alstublieft een UPN op."
            continue
        }

        try {
            $checkOwner = Get-MgUser -UserId $inputUpn -Property "id,displayName,accountEnabled" -ErrorAction Stop
            if ($checkOwner.AccountEnabled -ne $true) {
                Write-Warning "Gebruiker '$($checkOwner.DisplayName)' is niet actief (geblokkeerd). Kies een actieve gebruiker."
                continue
            }
            $algemeenOwnerUpn = $inputUpn
            Write-Host "Gebruiker '$($checkOwner.DisplayName)' ($algemeenOwnerUpn) geselecteerd als eigenaar." -ForegroundColor Green
        }
        catch {
            Write-Warning "Gebruiker '$inputUpn' kon niet worden gevonden. Controleer het e-mailadres en probeer het opnieuw. ($($_.Exception.Message))"
        }
    }

    # Roep de functie aan voor de specifieke Microsoft 365 groepen
    # De MailNickname voor "Algemeen" is hier 'algemeen' (lowercase) om te matchen met SharePoint URL conventies.
    Sync-UnifiedGroupAndTeam -DisplayName "Algemeen" -MailNickname "algemeen" -Description "Algemeen team voor alle medewerkers" -IsDynamic $true -MembershipRule '(user.userType -eq "Member")' -OwnerUpn $algemeenOwnerUpn -ActivateTeams $true # Expliciet Teams activeren
    Sync-UnifiedGroupAndTeam -DisplayName "Management" -MailNickname "Management" -Description "Team voor het management" -IsDynamic $false -ActivateTeams $false # AANPASSING HIER: Teams NIET activeren


    # --- Stap 5: Licenties toewijzen aan groepen ---
    Write-Host "`nStap 5: Licenties toewijzen aan groepen..." -ForegroundColor Yellow
    Write-Host "Wacht 30 seconden om Entra ID de tijd te geven de groepen te verwerken voor licentietoewijzing..."
    Start-Sleep -Seconds 30

    ################### Business Premium ##########################

    $targetGroupName_License_BP = "License-BusinessPremium" # Naam van de doelgroep voor Business Premium
    $skuBusinessPremiumFinal = $null # Deze variabele zal de uiteindelijke SkuId bevatten die gebruikt wordt

    # Interactieve prompt voor licentietoewijzing aan License-BusinessPremium
    $OutputYN = Read-Host "Voeg nu eerst handmatig een Business Premium licentie toe aan een gebruiker, Voer Y in wanneer dit gelukt is (Y/N)"
    If ($OutputYN -ne "Y" -and $OutputYN -ne "N") {
        Do {
            $OutputYN = Read-Host "Geef alstublieft 'Y' voor ja of 'N' voor nee in."
        } While ($OutputYN -ne "Y" -and $OutputYN -ne "N")
    }
    
    if ($OutputYN -eq "Y") { 
        $businessPremiumLicenseDisplayName = "Microsoft 365 Business Premium" # Displaynaam voor de prompt

        # Stap A: Zoek de doelgroep License-BusinessPremium (opnieuw ophalen voor zekerheid)
        Write-Host "`nStap A: Zoeken naar de doelgroep '$targetGroupName_License_BP'..." -ForegroundColor Yellow
        $targetGroup_BP = Get-MgGroup -Filter "displayName eq '$targetGroupName_License_BP'" | Select-Object -First 1 -ErrorAction Stop
        
        if ($targetGroup_BP.Count -gt 1) {
            throw "Meerdere groepen gevonden met de naam '$targetGroupName_License_BP'. Zorg voor een unieke groepsnaam."
        }
        Write-Host "Groep gevonden: $($targetGroup_BP.DisplayName) (ID: $($targetGroup_BP.Id))" -ForegroundColor Green

        # Stap B: Bepaal de Business Premium SkuId via een referentiegebruiker (interactief)
        while ($null -eq $skuBusinessPremiumFinal) {
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
                $skuBusinessPremiumFinal = $selectedSkuId
                Write-Host "SkuId '$skuBusinessPremiumFinal' geselecteerd voor licentietoewijzing." -ForegroundColor Green
            } else {
                Write-Warning "De ingevoerde SkuId '$selectedSkuId' is NIET gevonden bij de opgegeven gebruiker '$($refUser.DisplayName)'. Probeer het opnieuw."
            }
        }
    } else {
        Write-Host "Licentietoewijzing aan groep '$targetGroupName_License_BP' via interactieve methode overgeslagen. Terugval op automatische lookup..." -ForegroundColor Yellow
        $licentieNaam1_SkuPart = "BUSINESS_PREMIUM" # SkuPartNumber voor automatische lookup

        # Zoek de doelgroep License-BusinessPremium
        $targetGroup_BP = Get-MgGroup -Filter "displayName eq '$targetGroupName_License_BP'" | Select-Object -First 1 -ErrorAction SilentlyContinue
        if (-not $targetGroup_BP) {
            Write-Host "Groep '$targetGroupName_License_BP' niet gevonden voor licentietoewijzing." -ForegroundColor Yellow
        } else {
            $skuObj = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $licentieNaam1_SkuPart } | Select-Object -First 1
            if (-not $skuObj) {
                Write-Host "Automatische lookup: Licentie met SkuPartNumber '$licentieNaam1_SkuPart' niet gevonden in deze tenant." -ForegroundColor Red
                Write-Host "Controleer of de licentie actief is en de juiste SkuPartNumber wordt gebruikt." -ForegroundColor Red
            } else {
                $skuBusinessPremiumFinal = $skuObj.SkuId
                Write-Host "Automatische lookup: Licentie gevonden: $($skuObj.SkuPartNumber) (SkuId: $($skuBusinessPremiumFinal))" -ForegroundColor DarkCyan
            }
        }
    }

    # Common logic for applying Business Premium license after SKU is determined
    if ($skuBusinessPremiumFinal -and $targetGroup_BP) { # Controleer of zowel SKU als doelgroep zijn geïdentificeerd
        try {
            # Controleer of de licentie al is toegewezen om onnodige updates te voorkomen
            $currentGroupLicenses = (Get-MgGroup -GroupId $targetGroup_BP.Id -Property AssignedLicenses).AssignedLicenses | Select-Object -ExpandProperty SkuId
            if (-not ($currentGroupLicenses -contains $skuBusinessPremiumFinal)) {
                Set-MgGroupLicense -GroupId $targetGroup_BP.Id `
                                   -AddLicenses @{ SkuId = $skuBusinessPremiumFinal } `
                                   -RemoveLicenses @()
                Write-Host "Licentie '$licentieNaam1_SkuPart' succesvol toegewezen aan groep '$targetGroup_BP.DisplayName'." -ForegroundColor Green
            } else {
                Write-Host "Licentie '$licentieNaam1_SkuPart' is al toegewezen aan groep '$targetGroup_BP.DisplayName'. Overslaan." -ForegroundColor DarkCyan
            }
        } catch {
            Write-Host "Fout bij toewijzen licentie '$licentieNaam1_SkuPart' aan groep '$targetGroup_BP.DisplayName': $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Mogelijke oorzaken: Onvoldoende beschikbare licenties, of licentie kan niet aan groep worden toegewezen (check AssignedLicenses property in Graph)." -ForegroundColor Red
        }
    } else {
        Write-Host "Business Premium licentietoewijzing overgeslagen: Geen SKU of doelgroep gevonden/geselecteerd." -ForegroundColor Yellow
    }

    ################### Exchange Online ##########################
    # Dit deel blijft zoals het was, omdat hiervoor geen interactieve prompt is gevraagd.

    $groepNaam2 = "License-ExchangeOnline"
    $licentieNaam2 = "EXCHANGE_S_STANDARD" # Dit is de SkuPartNumber. Controleer dit in je tenant!

    $groep2 = Get-MgGroup -Filter "displayName eq '$groepNaam2'" | Select-Object -First 1 -ErrorAction SilentlyContinue

    if (-not $groep2) {
        Write-Host "Groep '$groepNa2' niet gevonden voor licentietoewijzing." -ForegroundColor Yellow
    } else {
        Write-Host "Groep gevonden: $($groep2.DisplayName) (ID: $($groep2.Id))" -ForegroundColor DarkCyan

        $sku2 = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $licentieNaam2 } | Select-Object -First 1

        if (-not $sku2) {
            Write-Host "Licentie met SkuPartNumber '$licentieNa2' niet gevonden in deze tenant." -ForegroundColor Red
            Write-Host "Controleer of de licentie actief is en de juiste SkuPartNumber wordt gebruikt." -ForegroundColor Red
        } else {
            Write-Host "Licentie gevonden: $($sku2.SkuPartNumber) (SkuId: $($sku2.SkuId))" -ForegroundColor DarkCyan

            try {
                # Controleer of de licentie al is toegewezen om onnodige updates te voorkomen
                $currentGroupLicenses = (Get-MgGroup -GroupId $groep2.Id -Property AssignedLicenses).AssignedLicenses | Select-Object -ExpandProperty SkuId
                if (-not ($currentGroupLicenses -contains $sku2.SkuId)) {
                    Set-MgGroupLicense -GroupId $groep2.Id `
                                    -AddLicenses @{ SkuId = $sku2.SkuId } `
                                    -RemoveLicenses @()
                    Write-Host "Licentie '$licentieNa2' succesvol toegewezen aan groep '$groepNa2'." -ForegroundColor Green
                } else {
                    Write-Host "Licentie '$licentieNa2' is al toegewezen aan groep '$groepNa2'. Overslaan." -ForegroundColor DarkCyan
                }
            } catch {
                Write-Host "Fout bij toewijzen licentie '$licentieNa2' aan groep '$groepNa2': $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Mogelijke oorzaken: Onvoldoende beschikbare licenties, of licentie kan niet aan groep worden toegewezen (check AssignedLicenses property in Graph)." -ForegroundColor Red
            }
        }
    }

} # Einde van het hoofd Try-blok
catch {
    Write-Error "Er is een kritieke fout opgetreden tijdens de uitvoering van het script: $($_.Exception.Message)"
    $_ | Format-List -Force # uncomment voor meer foutdetails bij kritieke fouten
}
finally {
    # Verbreek alle verbindingen netjes aan het einde van het script
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Write-Host "`nVerbinding met Microsoft Graph wordt verbroken."
        Disconnect-MgGraph
    }
    Write-Host "`nScript voltooid! Controleer de Entra ID en Teams portals voor de resultaten." -ForegroundColor DarkCyan
}