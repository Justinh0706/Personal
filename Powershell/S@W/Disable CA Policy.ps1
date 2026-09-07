<#
.SYNOPSIS
    Zet alle actieve Conditional Access policies in Entra ID terug naar 'report-only'.

.DESCRIPTION
    Tegenhanger van Enable-AllConditionalAccessPolicies.ps1 — bedoeld als
    noodrem/rollback: policies die nu 'enabled' (actief afdwingend) staan
    worden omgezet naar 'enabledForReportingButNotEnforced' (report-only).

    Policies die nu 'disabled' staan worden NIET aangeraakt — die zijn bewust
    uitgezet en report-only zou daar juist monitoring/logging aanzetten die
    er niet hoort te zijn.

    Geen script-parameters: bedoeld om als geheel (bv. via "Run" in VS Code /
    de PowerShell ISE) uitgevoerd te worden. Alle instellingen staan als
    variabelen bovenaan.

    Vóór elke wijziging wordt de volledige huidige policy-set weggeschreven
    naar een tijdgestempeld JSON-bestand, zodat je kunt terugrollen.

.NOTES
    Vereist module Microsoft.Graph.Identity.SignIns (en Authentication).
    Vereist Graph scopes: Policy.ReadWrite.ConditionalAccess, Policy.Read.All.

    BELANGRIJK - LEES DIT VOOR GEBRUIK IN PRODUCTIE:
    - Dit script verlaagt de handhaving van je Conditional Access beleid:
      policies loggen nog wel, maar blokkeren/vereisen niets meer (geen MFA-
      afdwinging, geen device-compliance check, geen locatie-restrictie, etc.).
      Dit is dus zelf ook een impactvolle wijziging op je beveiligingspostuur,
      niet alleen een "veilige" rollback-actie.
    - Gebruik dit gericht (bv. als een net doorgevoerde -Apply van het
      enable-script tot ongewenste lockouts leidt) en niet als permanente
      staat — report-only is een tijdelijke maatregel, geen eindstatus.
    - Gebruik de backup (JSON) om na afloop gericht terug te zetten naar de
      oorspronkelijke 'State' per policy, in plaats van dit script als
      permanente oplossing te laten staan.
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

# Policy Id's (guid's) die je expliciet wilt overslaan, ook als ze nu
# 'enabled' zijn — bv. je meest kritieke MFA-policy die je koste wat kost
# afgedwongen wilt houden, zelfs tijdens een rollback:
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
# Alleen policies die nu 'enabled' staan gaan naar 'enabledForReportingButNotEnforced'.
# 'disabled' policies worden bewust met rust gelaten.
$targetStates = @('enabled')

$toChange = $allPolicies | Where-Object {
    $targetStates -contains $_.State -and
    $ExcludePolicyId -notcontains $_.Id
}

$excludedButEnabled = $allPolicies | Where-Object {
    $targetStates -contains $_.State -and
    $ExcludePolicyId -contains $_.Id
}

if ($toChange.Count -eq 0) {
    Write-Host "Geen policies staan momenteel op 'enabled' (buiten expliciete excludes). Niets te doen." -ForegroundColor Green
    return
}

Write-Host "`n=== Policies die worden omgezet naar 'report-only' ===" -ForegroundColor Yellow
$toChange | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host

if ($excludedButEnabled.Count -gt 0) {
    Write-Host "=== Policies overgeslagen (expliciet uitgesloten via `$ExcludePolicyId, blijven 'enabled') ===" -ForegroundColor DarkYellow
    $excludedButEnabled | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host
}

# --- Dry-run: hier stoppen als $Apply = $false ------------------------------
if (-not $Apply) {
    Write-Host "DRY-RUN actief (`$Apply = `$false). Er is niets gewijzigd." -ForegroundColor Magenta
    Write-Host "Zet bovenaan het script `$Apply = `$true en run opnieuw om deze $($toChange.Count) policy/policies daadwerkelijk naar report-only te zetten." -ForegroundColor Magenta
    return
}

# --- Expliciete bevestiging vóór echte wijzigingen ---------------------------
if (-not $Force) {
    Write-Warning "Je staat op het punt om $($toChange.Count) Conditional Access policy/policies naar REPORT-ONLY te zetten in tenant $($context.TenantId)."
    Write-Warning "Deze policies handhaven daarna niets meer (geen MFA/device/locatie-afdwinging) — alleen logging blijft actief."
    $confirmation = Read-Host "Weet je zeker dat dit de gewenste (tijdelijke) beveiligingsimpact is? Type 'JA' om door te gaan"
    if ($confirmation -ne 'JA') {
        Write-Host "Afgebroken door gebruiker. Er is niets gewijzigd." -ForegroundColor Red
        return
    }
}

# --- Wijzigingen doorvoeren ---------------------------------------------------
$results = foreach ($policy in $toChange) {
    try {
        Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -BodyParameter @{ State = 'enabledForReportingButNotEnforced' }
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
    Write-Host "Alle policies zijn succesvol op 'report-only' gezet." -ForegroundColor Green
}

Write-Host "`nRollback: gebruik $backupFile om bij problemen de oorspronkelijke 'State' per policy-Id terug te zetten via Update-MgIdentityConditionalAccessPolicy." -ForegroundColor Cyan