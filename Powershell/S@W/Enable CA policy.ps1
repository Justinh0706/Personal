
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

function Invoke-CA-Policy-SetState {
    param(
        [ValidateSet('enabled', 'enabledForReportingButNotEnforced')]
        [string]$TargetState = 'enabled',
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
    if ($TargetState -eq 'enabled') {
        $sourceStates = @('enabledForReportingButNotEnforced')
        $friendlyTarget = 'enabled'
        $friendlyAction = "naar 'enabled'"
    }
    else {
        $sourceStates = @('enabled', 'disabled')
        $friendlyTarget = 'report-only'
        $friendlyAction = "naar 'enabledForReportingButNotEnforced'"
    }

    $toChange = $allPolicies | Where-Object {
        $sourceStates -contains $_.State -and
        $ExcludePolicyId -notcontains $_.Id
    }

    $excluded = $allPolicies | Where-Object {
        $sourceStates -contains $_.State -and
        $ExcludePolicyId -contains $_.Id
    }

    if ($toChange.Count -eq 0) {
        Write-Host "Alle policies (buiten expliciete excludes) staan al op '$friendlyTarget'. Niets te doen." -ForegroundColor Green
        return [PSCustomObject]@{
            BackupFile = $backupFile
            TargetState = $TargetState
            ToChange = @()
            Excluded = $excluded
            Apply = $Apply
            Result = 'NoAction'
        }
    }

    Write-Host "`n=== Policies die worden omgezet $friendlyAction ===" -ForegroundColor Yellow
    $toChange | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host

    if ($excluded.Count -gt 0) {
        Write-Host "=== Policies overgeslagen (expliciet uitgesloten via `$ExcludePolicyId) ===" -ForegroundColor DarkYellow
        $excluded | Select-Object DisplayName, Id, State | Format-Table -AutoSize | Out-String | Write-Host
    }

    if (-not $Apply) {
        Write-Host "DRY-RUN actief (`$Apply = `$false). Er is niets gewijzigd." -ForegroundColor Magenta
        Write-Host "Zet bovenaan het script `$Apply = `$true en run opnieuw om deze $($toChange.Count) policy/policies daadwerkelijk $friendlyAction te zetten." -ForegroundColor Magenta
        return [PSCustomObject]@{
            BackupFile = $backupFile
            TargetState = $TargetState
            ToChange = $toChange
            Excluded = $excluded
            Apply = $Apply
            Result = 'DryRun'
        }
    }

    $warningText = if ($TargetState -eq 'enabled') {
        "Je staat op het punt om $($toChange.Count) Conditional Access policy/policies te ENABLEN in tenant $($context.TenantId)."
    }
    else {
        "Je staat op het punt om $($toChange.Count) Conditional Access policy/policies terug te zetten naar REPORT-ONLY in tenant $($context.TenantId)."
    }

    if (-not $Force) {
        Write-Warning $warningText
        Write-Warning "Dit kan direct impact hebben op aanmeldingen van gebruikers én admins (lockout-risico)."
        $confirmation = Read-Host "Weet je zeker dat break-glass/emergency access accounts zijn uitgesloten en getest? Type 'JA' om door te gaan"
        if ($confirmation -ne 'JA') {
            Write-Host "Afgebroken door gebruiker. Er is niets gewijzigd." -ForegroundColor Red
            return [PSCustomObject]@{
                BackupFile = $backupFile
                TargetState = $TargetState
                ToChange = $toChange
                Excluded = $excluded
                Apply = $Apply
                Result = 'Cancelled'
            }
        }
    }

    $results = foreach ($policy in $toChange) {
        try {
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -BodyParameter @{ State = $TargetState }
            [PSCustomObject]@{
                DisplayName   = $policy.DisplayName
                Id            = $policy.Id
                PreviousState = $policy.State
                NewState      = $TargetState
                Result        = 'Succes'
                Error         = $null
            }
        }
        catch {
            [PSCustomObject]@{
                DisplayName   = $policy.DisplayName
                Id            = $policy.Id
                PreviousState = $policy.State
                NewState      = $TargetState
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
        Write-Host "Alle policies zijn succesvol $friendlyAction gezet." -ForegroundColor Green
    }

    Write-Host "`nRollback: gebruik $backupFile om bij problemen de oorspronkelijke 'State' per policy-Id terug te zetten via Update-MgIdentityConditionalAccessPolicy." -ForegroundColor Cyan

    return [PSCustomObject]@{
        BackupFile = $backupFile
        TargetState = $TargetState
        ToChange = $toChange
        Excluded = $excluded
        Apply = $Apply
        Result = if ($failed.Count -gt 0) { 'PartialFailure' } else { 'Success' }
        Details = $results
    }
}

function Invoke-CA-Policy-Enable {
    param(
        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string[]]$ExcludePolicyId = @()
    )

    return Invoke-CA-Policy-SetState -TargetState 'enabled' -Apply $Apply -Force $Force -ExcludePolicyId $ExcludePolicyId
}

function Invoke-CA-Policy-ReportOnly {
    param(
        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string[]]$ExcludePolicyId = @()
    )

    return Invoke-CA-Policy-SetState -TargetState 'enabledForReportingButNotEnforced' -Apply $Apply -Force $Force -ExcludePolicyId $ExcludePolicyId
}

function Connect-GraphFromGui {
    try {
        $requiredModule = 'Microsoft.Graph.Identity.SignIns'
        if (-not (Get-Module -ListAvailable -Name $requiredModule)) {
            throw "Module '$requiredModule' is niet geïnstalleerd. Installeer met: Install-Module $requiredModule -Scope CurrentUser"
        }

        Import-Module $requiredModule -ErrorAction Stop
        Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Policy.Read.All" -NoWelcome | Out-Null

        $context = Get-MgContext
        return "Verbonden met Microsoft Graph als: $($context.Account) (tenant: $($context.TenantId))"
    }
    catch {
        return "Fout bij verbinden met Microsoft Graph: $($_.Exception.Message)"
    }
}

function Disconnect-GraphFromGui {
    try {
        Disconnect-MgGraph | Out-Null
        return "Microsoft Graph sessie is verbroken."
    }
    catch {
        return "Fout bij verbreken van Microsoft Graph: $($_.Exception.Message)"
    }
}

function Confirm-CA-ActionDialog {
    param(
        [string]$Message,
        [string]$Title = 'Bevestiging'
    )

    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    return $result -eq [System.Windows.Forms.DialogResult]::Yes
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

    $targetLabel = New-Object System.Windows.Forms.Label
    $targetLabel.Text = 'Doelstatus:'
    $targetLabel.Location = New-Object System.Drawing.Point(20, 195)
    $targetLabel.Size = New-Object System.Drawing.Size(120, 24)
    $form.Controls.Add($targetLabel)

    $cmbTargetState = New-Object System.Windows.Forms.ComboBox
    $cmbTargetState.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbTargetState.Location = New-Object System.Drawing.Point(150, 192)
    $cmbTargetState.Size = New-Object System.Drawing.Size(180, 24)
    $cmbTargetState.Items.Add('Enabled') | Out-Null
    $cmbTargetState.Items.Add('Report-only') | Out-Null
    $cmbTargetState.SelectedIndex = 0
    $form.Controls.Add($cmbTargetState)

    $chkApply = New-Object System.Windows.Forms.CheckBox
    $chkApply.Text = 'Werkelijk uitvoeren (anders alleen dry-run)'
    $chkApply.Location = New-Object System.Drawing.Point(20, 230)
    $chkApply.Size = New-Object System.Drawing.Size(300, 24)
    $chkApply.Checked = $false
    $form.Controls.Add($chkApply)

    $chkForce = New-Object System.Windows.Forms.CheckBox
    $chkForce.Text = 'Sla bevestiging over (alleen bij echte uitvoering)'
    $chkForce.Location = New-Object System.Drawing.Point(20, 260)
    $chkForce.Size = New-Object System.Drawing.Size(340, 24)
    $chkForce.Checked = $false
    $form.Controls.Add($chkForce)

    $excludeLabel = New-Object System.Windows.Forms.Label
    $excludeLabel.Text = 'Uit te sluiten policy-id(s), gescheiden door komma:'
    $excludeLabel.Location = New-Object System.Drawing.Point(20, 305)
    $excludeLabel.Size = New-Object System.Drawing.Size(380, 24)
    $form.Controls.Add($excludeLabel)

    $txtExclude = New-Object System.Windows.Forms.TextBox
    $txtExclude.Location = New-Object System.Drawing.Point(20, 333)
    $txtExclude.Size = New-Object System.Drawing.Size(760, 24)
    $txtExclude.PlaceholderText = 'GUID-1, GUID-2'
    $form.Controls.Add($txtExclude)

    $btnConnect = New-Object System.Windows.Forms.Button
    $btnConnect.Text = 'Connect Graph'
    $btnConnect.Location = New-Object System.Drawing.Point(20, 375)
    $btnConnect.Size = New-Object System.Drawing.Size(120, 36)
    $form.Controls.Add($btnConnect)

    $btnDisconnect = New-Object System.Windows.Forms.Button
    $btnDisconnect.Text = 'Disconnect Graph'
    $btnDisconnect.Location = New-Object System.Drawing.Point(155, 375)
    $btnDisconnect.Size = New-Object System.Drawing.Size(150, 36)
    $form.Controls.Add($btnDisconnect)

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = 'Uitvoeren'
    $btnRun.Location = New-Object System.Drawing.Point(325, 375)
    $btnRun.Size = New-Object System.Drawing.Size(120, 36)
    $form.Controls.Add($btnRun)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Sluiten'
    $btnClose.Location = New-Object System.Drawing.Point(660, 375)
    $btnClose.Size = New-Object System.Drawing.Size(120, 36)
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnClose)

    $outputLabel = New-Object System.Windows.Forms.Label
    $outputLabel.Text = 'Uitvoer:'
    $outputLabel.Location = New-Object System.Drawing.Point(20, 425)
    $outputLabel.Size = New-Object System.Drawing.Size(120, 24)
    $form.Controls.Add($outputLabel)

    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Multiline = $true
    $txtOutput.ReadOnly = $true
    $txtOutput.ScrollBars = 'Both'
    $txtOutput.WordWrap = $false
    $txtOutput.Location = New-Object System.Drawing.Point(20, 455)
    $txtOutput.Size = New-Object System.Drawing.Size(760, 155)
    $txtOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
    $form.Controls.Add($txtOutput)

    $btnConnect.Add_Click({
        $txtOutput.Clear()
        $txtOutput.Text = Connect-GraphFromGui
    })

    $btnDisconnect.Add_Click({
        $txtOutput.Clear()
        $txtOutput.Text = Disconnect-GraphFromGui
    })

    $btnRun.Add_Click({
        $txtOutput.Clear()

        $selectedExclude = @()
        if ($txtExclude.Text) {
            $selectedExclude = ($txtExclude.Text -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }

        $targetState = if ($cmbTargetState.SelectedItem -eq 'Report-only') {
            'enabledForReportingButNotEnforced'
        }
        else {
            'enabled'
        }

        if ($chkApply.Checked -and -not $chkForce.Checked) {
            $actionText = if ($targetState -eq 'enabled') { 'ENABLEN' } else { 'terugzetten naar REPORT-ONLY' }
            $confirm = Confirm-CA-ActionDialog -Message "Je staat op het punt om de geselecteerde Conditional Access policies $actionText.`r`n`r`nControleer nogmaals of break-glass / emergency access accounts zijn uitgesloten.`r`n`r`nWil je doorgaan?" -Title 'Bevestiging Conditional Access wijziging'
            if (-not $confirm) {
                $txtOutput.Text = 'Afgebroken door gebruiker in de GUI. Er is niets gewijzigd.'
                return
            }
        }

        $btnRun.Enabled = $false
        $btnConnect.Enabled = $false
        $btnDisconnect.Enabled = $false
        $btnClose.Enabled = $false
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        try {
            $result = Invoke-CA-Policy-SetState -TargetState $targetState -Apply $chkApply.Checked -Force $true -ExcludePolicyId $selectedExclude

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
            $btnConnect.Enabled = $true
            $btnDisconnect.Enabled = $true
            $btnClose.Enabled = $true
        }
    })

    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

Show-CA-Policy-GUI