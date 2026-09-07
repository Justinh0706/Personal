<#
.SYNOPSIS
    Zet alle Conditional Access policies in Entra ID op status 'Enabled'.

.DESCRIPTION
    Haalt alle Conditional Access (CA) policies op via Microsoft Graph en zet
    policies die nu 'disabled' of 'enabledForReportingButNotEnforced' (report-only)
    staan om naar 'enabled'.

    Geen script-parameters: dit script is bedoeld om als geheel (bv. via "Run"
    in VS Code / de PowerShell ISE) uitgevoerd te worden. Alle instellingen
    staan als variabelen bovenaan — pas $Apply aan en run het script opnieuw
    in één keer, in plaats van het script met -Apply aan te roepen.

    Vóór elke wijziging wordt de volledige huidige policy-set weggeschreven naar
    een tijdgestempeld JSON-bestand, zodat je kunt terugrollen.

.NOTES
    Vereist module Microsoft.Graph.Identity.SignIns (en Authentication).
    Vereist Graph scopes: Policy.ReadWrite.ConditionalAccess, Policy.Read.All.

    BELANGRIJK - LEES DIT VOOR GEBRUIK IN PRODUCTIE:
    - Bulk-enablen van alle CA policies tegelijk kan gebruikers ÉN admins
      direct buitensluiten (lockout), zeker als report-only policies ineens
      worden afgedwongen.
    - Controleer VOORAF dat je break-glass / emergency access accounts hebt
      die zijn uitgesloten van (alle) Conditional Access policies. Dit script
      controleert dat niet automatisch — dat is een menselijke check.
    - Voer dit bij voorkeur eerst uit met $Apply = $false (dry-run), controleer
      de lijst, en run daarna pas met $Apply = $true — bij voorkeur buiten
      kantooruren met iemand achter de hand die alternatieve toegang heeft.
    - Gebruik de backup (JSON) om bij problemen de oude 'State' waarden
      terug te zetten per policy.
#>

# ============================================================
# CONFIGURATIE — pas hier aan en run het script als geheel
# ============================================================

# $false = dry-run: toont alleen wat er zou wijzigen, past niets toe.
# $true  = voert de wijzigingen echt door (na bevestiging, tenzij $Force).
$Apply = $false

# $true = sla de handmatige bevestigingsvraag over bij $Apply = $true.
# Gebruik alleen als je de impact al hebt gevalideerd (bv. via eerdere dry-run).
$Force = $false

# Policy Id's (guid's) die je expliciet wilt overslaan, ook als ze niet
# 'enabled' zijn. Gebruik dit voor policies die bewust uit staan of nog in
# pilot/test zijn, bv:
# $ExcludePolicyId = @("11111111-2222-3333-4444-555555555555")
$ExcludePolicyId = @()

# Map waarin het backup-JSON-bestand wordt weggeschreven.
$BackupPath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ============================================================
# SCRIPT — onderstaande hoeft normaliter niet aangepast te worden
# ============================================================

$ErrorActionPreference = 'Stop'

# --- Vereiste module controleren -------------------------------------------
$requiredModule = 'Microsoft.Graph.Identity.SignIns'
if (-not (Get-Module -ListAvailable -Name $requiredModule)) {
    Write-Error "Module '$requiredModule' is niet geïnstalleerd. Installeer met: Install-Module $requiredModule -Scope CurrentUser"
    return
}
Import-Module $requiredModule -ErrorAction Stop

# --- Verbinden met Microsoft Graph ------------------------------------------
# Interactieve login: geen secrets/credentials in dit script. De ingelogde
# account heeft minimaal Conditional Access Administrator (of hoger) nodig.
Write-Host "Verbinden met Microsoft Graph (interactieve login)..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Policy.Read.All" -NoWelcome

$context = Get-MgContext
Write-Host "Verbonden als: $($context.Account) (tenant: $($context.TenantId))" -ForegroundColor Cyan

# --- Alle CA policies ophalen ------------------------------------------------
Write-Host "Ophalen van alle Conditional Access policies..." -ForegroundColor Cyan
$allPolicies = Get-MgIdentityConditionalAccessPolicy -All

if (-not $allPolicies -or $allPolicies.Count -eq 0) {
    Write-Warning "Geen Conditional Access policies gevonden in deze tenant."
    return
}

Write-Host "Gevonden: $($allPolicies.Count) policies totaal." -ForegroundColor Cyan

# --- Backup wegschrijven (altijd, ook in dry-run) ---------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = Join-Path -Path $BackupPath -ChildPath "CAPolicy-backup-$timestamp.json"

$backupData = $allPolicies | ForEach-Object {
    [PSCustomObject]@{
        Id          = $_.Id
        DisplayName = $_.DisplayName
        State       = $_.State
    }
}
$backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding utf8
Write-Host "Backup van huidige policy-states weggeschreven naar: $backupFile" -ForegroundColor Green

# --- Bepalen welke policies gewijzigd moeten worden -------------------------
# Doelstatussen die worden omgezet naar 'enabled': 'disabled' en
# 'enabledForReportingButNotEnforced' (report-only).
$targetStates = @('disabled', 'enabledForReportingButNotEnforced')

$toChange = $allPolicies | Where-Object {
    $targetStates -contains $_.State -and
    $ExcludePolicyId -notcontains $_.Id
}

$excludedButNotEnabled = $allPolicies | Where-Object {
    $targetStates -contains $_.State -and
    $ExcludePolicyId -contains $_.Id
}

if ($toChange.Count -eq 0) {
    Write-Host "Alle policies (buiten expliciete excludes) staan al op 'enabled'. Niets te doen." -ForegroundColor Green
    return
}

Write-Host "`n=== Policies die worden omgezet naar 'enabled' ===" -ForegroundColor Yellow
$toChange | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host

if ($excludedButNotEnabled.Count -gt 0) {
    Write-Host "=== Policies overgeslagen (expliciet uitgesloten via `$ExcludePolicyId) ===" -ForegroundColor DarkYellow
    $excludedButNotEnabled | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host
}

# --- Dry-run: hier stoppen als $Apply = $false ------------------------------
if (-not $Apply) {
    Write-Host "DRY-RUN actief (`$Apply = `$false). Er is niets gewijzigd." -ForegroundColor Magenta
    Write-Host "Zet bovenaan het script `$Apply = `$true en run opnieuw om deze $($toChange.Count) policy/policies daadwerkelijk te enablen." -ForegroundColor Magenta
    return
}

# --- Expliciete bevestiging vóór echte wijzigingen ---------------------------
if (-not $Force) {
    Write-Warning "Je staat op het punt om $($toChange.Count) Conditional Access policy/policies te ENABLEN in tenant $($context.TenantId)."
    Write-Warning "Dit kan direct impact hebben op aanmeldingen van gebruikers én admins (lockout-risico)."
    $confirmation = Read-Host "Weet je zeker dat break-glass/emergency access accounts zijn uitgesloten en getest? Type 'JA' om door te gaan"
    if ($confirmation -ne 'JA') {
        Write-Host "Afgebroken door gebruiker. Er is niets gewijzigd." -ForegroundColor Red
        return
    }
}

# --- Wijzigingen doorvoeren ---------------------------------------------------
$results = foreach ($policy in $toChange) {
    try {
        Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -BodyParameter @{ State = 'enabled' }
        [PSCustomObject]@{
            DisplayName   = $policy.DisplayName
            Id            = $policy.Id
            PreviousState = $policy.State
            Result        = 'Succes'
            Error         = $null
        }
    }
    catch {
        [PSCustomObject]@{
            DisplayName   = $policy.DisplayName
            Id            = $policy.Id
            PreviousState = $policy.State
            Result        = 'Mislukt'
            Error         = $_.Exception.Message
        }
    }
}

Write-Host "`n=== Resultaat ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host

$failed = $results | Where-Object { $_.Result -eq 'Mislukt' }
if ($failed.Count -gt 0) {
    Write-Warning "$($failed.Count) policy/policies konden niet worden gewijzigd. Zie kolom 'Error' hierboven."
}
else {
    Write-Host "Alle policies zijn succesvol op 'enabled' gezet." -ForegroundColor Green
}

Write-Host "`nRollback: gebruik $backupFile om bij problemen de oorspronkelijke 'State' per policy-Id terug te zetten via Update-MgIdentityConditionalAccessPolicy." -ForegroundColor Cyan