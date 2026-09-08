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

    # Alleen standaard Microsoft 365 groepen; geen security-, dynamic-, device- of licentie-groepen meer.
    Write-Host "`nAanmaken van standaard Microsoft 365 groepen..." -ForegroundColor Yellow
    New-MgGroup -DisplayName "Management" -MailEnabled:$True -MailNickName "management" -SecurityEnabled:$True -GroupTypes @("Unified")
    Write-Host "Standaard Microsoft 365 groepen succesvol aangemaakt." -ForegroundColor Green

    Write-Host "`nWacht 5 seconden voor groepspropagatie..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    ##### Eigenaar toevoegen aan de Algemeen-groep en Teams activeren (zonder licentie-assignment) #####
    $groupNameToSearch_Owner = "Algemeen"
    $algemeenGroupForOwner = Get-MgGroup -Filter "displayName eq '$groupNameToSearch_Owner'" | Select-Object -First 1

    if (-not $algemeenGroupForOwner) {
        throw "Groep '$groupNameToSearch_Owner' is na aanmaak niet gevonden. Kan geen eigenaar toevoegen."
    }

    $validOwner = $null
    while ($null -eq $validOwner) {
        Write-Host "`nStap A: Groepseigenaar selecteren voor groep '$groupNameToSearch_Owner'." -ForegroundColor Yellow
        $ownerUserPrincipalName = Read-Host "Geef de UPN (e-mailadres) op van de gebruiker die eigenaar moet worden van de groep"

        if ([string]::IsNullOrWhiteSpace($ownerUserPrincipalName)) {
            Write-Warning "Invoer is leeg. Probeer het opnieuw."
            continue
        }

        try {
            $potentialOwner = Get-MgUser -UserId $ownerUserPrincipalName -Property "id,displayName,accountEnabled" -ErrorAction Stop
        }
        catch {
            Write-Warning "Gebruiker '$ownerUserPrincipalName' kon niet worden gevonden. Controleer het e-mailadres en probeer het opnieuw."
            continue
        }

        if ($potentialOwner.AccountEnabled -ne $true) {
            Write-Warning "Gebruiker '$($potentialOwner.DisplayName)' is niet actief (geblokkeerd). Kies een actieve gebruiker."
            continue
        }

        $validOwner = $potentialOwner
    }

    Write-Host "`nStap B: Controleren en toevoegen van eigenaar..." -ForegroundColor Yellow
    $currentOwners = Get-MgGroupOwner -GroupId $algemeenGroupForOwner.Id

    if ($validOwner.Id -in $currentOwners.Id) {
        Write-Host "$($validOwner.DisplayName) is al eigenaar van de groep '$($algemeenGroupForOwner.DisplayName)'." -ForegroundColor Cyan
    }
    else {
        New-MgGroupOwner -GroupId $algemeenGroupForOwner.Id -DirectoryObjectId $validOwner.Id
        Write-Host "SUCCES! '$($validOwner.DisplayName)' is nu eigenaar van de groep '$($algemeenGroupForOwner.DisplayName)'." -ForegroundColor Green
    }

    Start-Sleep -Seconds 5

    Write-Host "`nTeams activeren voor groep '$($algemeenGroupForOwner.DisplayName)'..." -ForegroundColor Yellow
    try {
        $uri = "https://graph.microsoft.com/v1.0/groups/$($algemeenGroupForOwner.Id)/team"
        $body = @{
            memberSettings = @{
                allowCreateUpdateChannels = $true
            }
            messagingSettings = @{
                allowUserEditMessages = $true
            }
        } | ConvertTo-Json -Depth 5

        Invoke-MgGraphRequest -Method PUT -Uri $uri -Body $body -ErrorAction Stop
        Write-Host "Teams succesvol geactiveerd voor groep '$($algemeenGroupForOwner.DisplayName)'" -ForegroundColor Green
    }
    catch {
        Write-Warning "Fout bij activeren van Teams op groep '$($algemeenGroupForOwner.DisplayName)': $($_.Exception.Message)"
        Write-Warning "Controleer of de groep voldoet aan de eisen voor Teams en of de geselecteerde eigenaar correct is."
    }

    ##### Eigenaar toevoegen aan Management-groep en Teams activeren #####
    Write-Host "`n--- Management Groep Configuratie ---" -ForegroundColor Cyan
    $managementGroupName = "Management"
    $managementGroupForOwner = Get-MgGroup -Filter "displayName eq '$managementGroupName'" | Select-Object -First 1

    if (-not $managementGroupForOwner) {
        Write-Warning "Groep '$managementGroupName' kon niet worden gevonden. Management configuratie overgeslagen."
    }
    else {
        Write-Host "`nDezelfde gebruiker '$($validOwner.DisplayName)' wordt ook eigenaar van de groep '$managementGroupName'." -ForegroundColor Yellow

        $currentManagementOwners = Get-MgGroupOwner -GroupId $managementGroupForOwner.Id

        if ($validOwner.Id -in $currentManagementOwners.Id) {
            Write-Host "$($validOwner.DisplayName) is al eigenaar van de groep '$($managementGroupForOwner.DisplayName)'." -ForegroundColor Cyan
        }
        else {
            try {
                New-MgGroupOwner -GroupId $managementGroupForOwner.Id -DirectoryObjectId $validOwner.Id
                Write-Host "SUCCES! '$($validOwner.DisplayName)' is nu eigenaar van de groep '$($managementGroupForOwner.DisplayName)'." -ForegroundColor Green
            }
            catch {
                Write-Warning "Fout bij toevoegen van eigenaar aan Management groep: $($_.Exception.Message)"
            }
        }

        Start-Sleep -Seconds 5

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
        }
        catch {
            Write-Warning "Fout bij activeren van Teams op groep '$($managementGroupForOwner.DisplayName)': $($_.Exception.Message)"
            Write-Warning "Controleer of de groep voldoet aan de eisen voor Teams en of de eigenaar correct is."
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