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

function Invoke-CA-Policy-Enable {
    param(
        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string[]]$ExcludePolicyId = @()
    )

    $ErrorActionPreference = 'Stop'

    # --- Vereiste module controleren -------------------------------------------
    $requiredModule = 'Microsoft.Graph.Identity.SignIns'
    if (-not (Get-Module -ListAvailable -Name $requiredModule)) {
        Write-Error "Module '$requiredModule' is niet geïnstalleerd. Installeer met: Install-Module $requiredModule -Scope CurrentUser"
        return
    }
    Import-Module $requiredModule -ErrorAction Stop

    # --- Verbinden met Microsoft Graph ------------------------------------------
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
    $targetStates = @('enabledForReportingButNotEnforced')

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
        return [PSCustomObject]@{
            BackupFile = $backupFile
            ToChange = @()
            Excluded = $excludedButNotEnabled
            Apply = $Apply
            Result = 'NoAction'
        }
    }

    Write-Host "`n=== Policies die worden omgezet naar 'enabled' ===" -ForegroundColor Yellow
    $toChange | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host

    if ($excludedButNotEnabled.Count -gt 0) {
        Write-Host "=== Policies overgeslagen (expliciet uitgesloten via `$ExcludePolicyId) ===" -ForegroundColor DarkYellow
        $excludedButNotEnabled | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host
    }

    if (-not $Apply) {
        Write-Host "DRY-RUN actief (`$Apply = `$false). Er is niets gewijzigd." -ForegroundColor Magenta
        Write-Host "Zet bovenaan het script `$Apply = `$true en run opnieuw om deze $($toChange.Count) policy/policies daadwerkelijk te enablen." -ForegroundColor Magenta
        return [PSCustomObject]@{
            BackupFile = $backupFile
            ToChange = $toChange
            Excluded = $excludedButNotEnabled
            Apply = $Apply
            Result = 'DryRun'
        }
    }

    if (-not $Force) {
        Write-Warning "Je staat op het punt om $($toChange.Count) Conditional Access policy/policies te ENABLEN in tenant $($context.TenantId)."
        Write-Warning "Dit kan direct impact hebben op aanmeldingen van gebruikers én admins (lockout-risico)."
        $confirmation = Read-Host "Weet je zeker dat break-glass/emergency access accounts zijn uitgesloten en getest? Type 'JA' om door te gaan"
        if ($confirmation -ne 'JA') {
            Write-Host "Afgebroken door gebruiker. Er is niets gewijzigd." -ForegroundColor Red
            return [PSCustomObject]@{
                BackupFile = $backupFile
                ToChange = $toChange
                Excluded = $excludedButNotEnabled
                Apply = $Apply
                Result = 'Cancelled'
            }
        }
    }

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

    return [PSCustomObject]@{
        BackupFile = $backupFile
        ToChange = $toChange
        Excluded = $excludedButNotEnabled
        Apply = $Apply
        Result = if ($failed.Count -gt 0) { 'PartialFailure' } else { 'Success' }
        Details = $results
    }
}

function Show-CA-Policy-GUI {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Conditional Access policy activator'
    $form.Size = New-Object System.Drawing.Size(820, 680)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'Conditional Access policies activeren'
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(420, 32)
    $form.Controls.Add($titleLabel)

    $warningBox = New-Object System.Windows.Forms.TextBox
    $warningBox.Multiline = $true
    $warningBox.ReadOnly = $true
    $warningBox.ScrollBars = 'Vertical'
    $warningBox.Location = New-Object System.Drawing.Point(20, 60)
    $warningBox.Size = New-Object System.Drawing.Size(760, 120)
    $warningBox.Text = "Let op:`r`n- Deze actie zet report-only Conditional Access policies om naar Enabled.`r`n- Controleer vooraf of break-glass / emergency access accounts zijn uitgesloten.`r`n- Gebruik eerst de dry-run om te controleren wat er gewijzigd zou worden."
    $form.Controls.Add($warningBox)

    $chkApply = New-Object System.Windows.Forms.CheckBox
    $chkApply.Text = 'Werkelijk uitvoeren (anders alleen dry-run)'
    $chkApply.Location = New-Object System.Drawing.Point(20, 195)
    $chkApply.Size = New-Object System.Drawing.Size(300, 24)
    $chkApply.Checked = $false
    $form.Controls.Add($chkApply)

    $chkForce = New-Object System.Windows.Forms.CheckBox
    $chkForce.Text = 'Sla bevestiging over (alleen bij echte uitvoering)'
    $chkForce.Location = New-Object System.Drawing.Point(20, 225)
    $chkForce.Size = New-Object System.Drawing.Size(340, 24)
    $chkForce.Checked = $false
    $form.Controls.Add($chkForce)

    $excludeLabel = New-Object System.Windows.Forms.Label
    $excludeLabel.Text = 'Uit te sluiten policy-id(s), gescheiden door komma:'
    $excludeLabel.Location = New-Object System.Drawing.Point(20, 270)
    $excludeLabel.Size = New-Object System.Drawing.Size(380, 24)
    $form.Controls.Add($excludeLabel)

    $txtExclude = New-Object System.Windows.Forms.TextBox
    $txtExclude.Location = New-Object System.Drawing.Point(20, 298)
    $txtExclude.Size = New-Object System.Drawing.Size(760, 24)
    $txtExclude.PlaceholderText = 'GUID-1, GUID-2'
    $form.Controls.Add($txtExclude)

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = 'Uitvoeren'
    $btnRun.Location = New-Object System.Drawing.Point(20, 340)
    $btnRun.Size = New-Object System.Drawing.Size(120, 36)
    $form.Controls.Add($btnRun)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Sluiten'
    $btnClose.Location = New-Object System.Drawing.Point(660, 340)
    $btnClose.Size = New-Object System.Drawing.Size(120, 36)
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnClose)

    $outputLabel = New-Object System.Windows.Forms.Label
    $outputLabel.Text = 'Uitvoer:'
    $outputLabel.Location = New-Object System.Drawing.Point(20, 390)
    $outputLabel.Size = New-Object System.Drawing.Size(120, 24)
    $form.Controls.Add($outputLabel)

    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Multiline = $true
    $txtOutput.ReadOnly = $true
    $txtOutput.ScrollBars = 'Both'
    $txtOutput.WordWrap = $false
    $txtOutput.Location = New-Object System.Drawing.Point(20, 420)
    $txtOutput.Size = New-Object System.Drawing.Size(760, 190)
    $txtOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
    $form.Controls.Add($txtOutput)

    $btnRun.Add_Click({
        $txtOutput.Clear()

        $selectedExclude = @()
        if ($txtExclude.Text) {
            $selectedExclude = ($txtExclude.Text -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }

        $btnRun.Enabled = $false
        $btnClose.Enabled = $false
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        try {
            $result = Invoke-CA-Policy-Enable -Apply $chkApply.Checked -Force $chkForce.Checked -ExcludePolicyId $selectedExclude

            if ($null -eq $result) {
                $txtOutput.Text = 'Geen resultaat teruggekregen.'
            }
            elseif ($result -is [System.Collections.IEnumerable] -and -not ($result -is [string])) {
                $txtOutput.Text = ($result | Format-Table -AutoSize | Out-String)
            }
            else {
                $txtOutput.Text = ($result | Out-String)
            }
        }
        catch {
            $txtOutput.Text = "Fout: $($_.Exception.Message)"
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnRun.Enabled = $true
            $btnClose.Enabled = $true
        }
    })

    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

Show-CA-Policy-GUI