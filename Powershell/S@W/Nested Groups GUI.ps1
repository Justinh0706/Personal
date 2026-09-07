<#
.SYNOPSIS
    Visual (WinForms) front end for Add-NestedGroupMembership.ps1.

.DESCRIPTION
    A GUI wrapper so customers don't need to know PowerShell flags to run
    Check, Apply, Create-missing-groups, or Remove-unexpected-members. It
    does NOT reimplement any of that logic -- it calls the exact same,
    already-tested Add-NestedGroupMembership.ps1 script in this folder, so
    every safety behaviour built into that script (never deletes a group,
    removal requires explicit opt-in, HTML/CSV reports, preflight checks,
    the drift detection, all of it) applies here unchanged.

    ARCHITECTURE -- read this before changing how the GUI connects or runs:

    1. Sign-in happens directly on the GUI's own thread (the "Connect"
       button), not inside the background work. This is deliberate: the
       Microsoft Graph SDK's device-code prompt only prints correctly to a
       real, non-redirected console (see msgraph-sdk-powershell#2798) --
       capturing/redirecting that output the way a background job normally
       would silently hides the code and the sign-in hangs until it times
       out. Doing it in the foreground avoids that entirely.

    2. The actual Check/Apply/Create/Remove work runs in a background
       PowerShell Runspace inside THIS SAME PROCESS (not a new powershell.exe
       process), so the window doesn't freeze. This only works because the
       SDK's authentication context is a single PER-PROCESS singleton, shared
       across every runspace in that process (confirmed in the SDK's own
       GitHub issue #2543 -- it's actually a complaint from other users who
       wanted per-runspace isolation and don't have it). That's why sign-in
       done in step 1 is visible to the background work in step 2 without
       reconnecting. Cross-PROCESS token reuse, by contrast, is currently
       unreliable in the SDK (see issue #3587) -- which is exactly why this
       script never shells out to a new powershell.exe for the actual work.

    3. The GUI always passes -Force (skip the CLI's own interactive
       "already connected?" prompt -- this window's Connection panel and
       Connect/Disconnect buttons replace it) and -Confirm:$false (skip the
       CLI's own per-item removal confirmation -- the GUI's own upfront
       "are you sure?" dialog before a Remove run replaces it, since a
       background runspace has no way to answer an interactive host prompt
       and would otherwise hang or fail).

    4. Output is captured by reading the background PowerShell instance's
       Warning/Error/Information streams on a timer, rather than trying to
       marshal live events across threads -- PSDataCollection (what those
       streams are) is explicitly thread-safe for this producer/consumer
       pattern, and a WinForms Timer already ticks on the UI thread, so no
       manual cross-thread Invoke() is needed. Write-Host output specifically
       comes through as InformationRecord objects with the original
       -ForegroundColor preserved (PowerShell 5+ behaviour), which is why the
       log below shows the same colours as running the script from a console.

    This is new code and, unlike the two CLI scripts, hasn't been run yet --
    there's no Windows/PowerShell/Graph environment available to test it
    against a live tenant. Treat the first run the same way we treated the
    CLI scripts' first runs: expect to iterate, and if something fails,
    the exact error and line number matter more than a guess.

.PARAMETER ScriptDirectory
    Folder containing Add-NestedGroupMembership.ps1. Defaults to wherever
    this GUI script itself is being run from -- keep both files together.

.PARAMETER ShowConsoleWindow
    Keeps the console window this script was launched from visible.
    Off by default, so customers only ever see the GUI -- same pattern
    IntuneManagement uses. Turn this on for your own troubleshooting; it
    doesn't affect the separate windows the fallback sign-in/run paths
    open when needed, which stay visible either way since those are ones
    a person has to actually interact with.

.EXAMPLE
    .\NestedGroupMembership-GUI.ps1

    Launches the GUI, expecting Add-NestedGroupMembership.ps1 in the same folder.

.EXAMPLE
    .\NestedGroupMembership-GUI.ps1 -ShowConsoleWindow

    Same, but leaves the launching console window visible -- useful when
    troubleshooting, e.g. Start-NestedGroupMembershipGUI-WithConsole.cmd.
#>
[CmdletBinding()]
param(
    [string]$ScriptDirectory = $PSScriptRoot,

    # Off by default so customers only ever see the GUI, never a console
    # window -- same pattern IntuneManagement uses (its Start-WithConsole
    # variants pass the equivalent switch for troubleshooting). This does
    # NOT affect the separate windows the fallback sign-in/run paths open
    # when needed -- those stay visible on purpose, since they're the ones
    # a person actually has to interact with.
    [switch]$ShowConsoleWindow
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# PowerShell hosts WinForms without the DPI-awareness manifest a real
# compiled app would have, which is a well-known cause of controls (like
# an anchored button in a GroupBox) not painting correctly on first show,
# even though they're actually positioned correctly -- fixed the moment
# anything forces a repaint (e.g. resizing the window). Setting this
# explicitly, before any control is created, is the standard fix.
try {
    [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::SystemAware) | Out-Null
}
catch {
    # Non-fatal -- older .NET/PowerShell combinations may not expose this;
    # the Shown-handler repaint below still covers the same symptom.
}

[System.Windows.Forms.Application]::EnableVisualStyles()

if (-not $ShowConsoleWindow) {
    # Hides the console window this script was launched from -- the
    # process and its console buffer still exist underneath (PowerShell is
    # a console-subsystem executable, that part can't be avoided), but
    # nothing about it stays visible on screen. Purely a window-state
    # change; doesn't affect anything this script actually does. Run with
    # -ShowConsoleWindow to see it for troubleshooting.
    try {
        Add-Type -Name Window -Namespace ConsoleHelper -MemberDefinition '
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
        $consoleHandle = [ConsoleHelper.Window]::GetConsoleWindow()
        if ($consoleHandle -ne [IntPtr]::Zero) {
            [ConsoleHelper.Window]::ShowWindow($consoleHandle, 0) | Out-Null  # 0 = SW_HIDE
        }
    }
    catch {
        # Non-fatal -- worst case the console just stays visible.
    }
}

# --- Global safety net -------------------------------------------------------
# Connect-MgGraph runs synchronously on the UI thread during sign-in (see the
# Connect button handler below) -- deliberately, since running it in a
# background runspace risks silently hiding the device-code prompt the same
# way capturing its output does (msgraph-sdk-powershell#2798). The tradeoff:
# the window is genuinely unresponsive for however long sign-in takes, and if
# that gets interrupted (the window force-closed, Windows flagging it as
# hung, etc.), PowerShell can throw a PipelineStoppedException that bypasses
# normal try/catch -- this is documented engine behaviour when a pipeline is
# externally stopped, not a bug in the try/catch below. Without a handler
# here, that becomes a raw, ugly "unhandled exception in a component of your
# application" crash dialog instead of a message the app can recover from.
try {
    # Must be set before any Control is ever created on this thread, and
    # only once -- fails if the GUI has already been run earlier in this
    # same PowerShell session (re-running .\NestedGroupMembership-GUI.ps1
    # repeatedly in one window is exactly that case). Harmless to skip: the
    # thread already has whatever mode got set the first time this session,
    # and the freeze this was originally guarding against is fixed at the
    # root now anyway (Connect runs in a background runspace, not on this
    # thread) -- this is just an extra safety net, not load-bearing.
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
}
catch {
    Write-Warning "Couldn't set unhandled-exception mode (likely because the GUI already ran once in this session) -- continuing without it. Start a fresh PowerShell window if you want this safety net active."
}
[System.Windows.Forms.Application]::add_ThreadException({
    param($exSender, $exArgs)
    try {
        [System.Windows.Forms.MessageBox]::Show(
            "Something interrupted the last action.`n`nDetails: $($exArgs.Exception.Message)`n`nThe app is still open and safe to keep using.",
            'Recovered from an interruption', 'OK', 'Warning') | Out-Null
    }
    catch {}
    # Best-effort recovery: whatever was in flight is gone, so put the UI
    # back into a known-good, usable state rather than leaving buttons
    # stuck disabled from whatever action was interrupted.
    try {
        $btnRun.Enabled = $true
        $btnCancel.Enabled = $false
        $progress.Visible = $false
        [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
    }
    catch {}
})

$mainScriptPath = Join-Path $ScriptDirectory 'Add-NestedGroupMembership.ps1'
if (-not (Test-Path $mainScriptPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Can't find Add-NestedGroupMembership.ps1 in:`n$ScriptDirectory`n`nPlace this GUI script in the same folder as that script.",
        'Missing script', 'OK', 'Error') | Out-Null
    return
}

# =============================================================================
# Helpers
# =============================================================================

# Maps Write-Host -ForegroundColor (a ConsoleColor) to a WinForms drawing
# color, so the log box reproduces the exact same colour scheme the CLI
# script already uses (Cyan=info, Green=success, Yellow=warning, Red=error/
# removal, Magenta=the connection banner).
$script:ConsoleColorMap = @{
    Black       = [System.Drawing.Color]::Black
    DarkBlue    = [System.Drawing.Color]::DarkBlue
    DarkGreen   = [System.Drawing.Color]::DarkGreen
    DarkCyan    = [System.Drawing.Color]::DarkCyan
    DarkRed     = [System.Drawing.Color]::DarkRed
    DarkMagenta = [System.Drawing.Color]::DarkMagenta
    DarkYellow  = [System.Drawing.Color]::Olive
    Gray        = [System.Drawing.Color]::Gray
    DarkGray    = [System.Drawing.Color]::DarkGray
    Blue        = [System.Drawing.Color]::RoyalBlue
    Green       = [System.Drawing.Color]::ForestGreen
    Cyan        = [System.Drawing.Color]::DarkCyan
    Red         = [System.Drawing.Color]::Firebrick
    Magenta     = [System.Drawing.Color]::MediumVioletRed
    Yellow      = [System.Drawing.Color]::DarkGoldenrod
    White       = [System.Drawing.Color]::Black   # white-on-white would be invisible on the log's white background
}

function Add-LogLine {
    param(
        [Parameter(Mandatory)][string]$Text,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::Black
    )
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionLength = 0
    $txtLog.SelectionColor = $Color
    $txtLog.AppendText("$Text`r`n")
    $txtLog.ScrollToCaret()
}

function Start-ConsoleCommand {
    # Runs $Command in a genuinely new, top-level console window via a temp
    # .ps1 file, launched with -File rather than -Command. This deliberately
    # avoids passing a complex, space-and-quote-heavy string through
    # Start-Process's -ArgumentList array: that parameter has a well-known,
    # documented history of not reliably preserving such a string as one
    # token on the way to the child process's command line (it can get
    # split apart, silently breaking the command) -- a single file path
    # has no such ambiguity. Returns the launched Process object, or $null
    # if it couldn't be started (caller should check for that).
    param([Parameter(Mandatory)][string]$Command)

    $tempScriptPath = Join-Path $env:TEMP ("NGM_{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
    try {
        Set-Content -Path $tempScriptPath -Value $Command -Encoding UTF8
        $exePath = (Get-Process -Id $PID).Path
        $proc = Start-Process -FilePath $exePath -ArgumentList @('-NoExit', '-File', $tempScriptPath) -PassThru
        return $proc
    }
    catch {
        Add-LogLine "Couldn't open a new console window: $($_.Exception.Message)" $script:ConsoleColorMap.Red
        return $null
    }
}

# =============================================================================
# Embedded brand assets (Secure At Work) -- base64 so this stays a single
# portable .ps1 file with no separate image files to lose track of.
# =============================================================================
$script:BrandPrimary = [System.Drawing.Color]::FromArgb(43, 87, 167)   # #2b57a7
$script:BrandDark    = [System.Drawing.Color]::FromArgb(33, 65, 131)   # #214183

$script:LogoBase64 = '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'
$script:IconBase64 = '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'

$script:LogoImage = $null
$script:AppIcon = $null
try {
    $logoBytes = [Convert]::FromBase64String($script:LogoBase64)
    $logoStream = [System.IO.MemoryStream]::new($logoBytes)
    $script:LogoImage = [System.Drawing.Image]::FromStream($logoStream)
}
catch {
    Write-Warning "Could not load embedded logo: $($_.Exception.Message)"
}
try {
    $iconBytes = [Convert]::FromBase64String($script:IconBase64)
    $iconStream = [System.IO.MemoryStream]::new($iconBytes)
    $script:AppIcon = New-Object System.Drawing.Icon($iconStream)
}
catch {
    Write-Warning "Could not load embedded icon: $($_.Exception.Message)"
}

# =============================================================================
# Form layout
# =============================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Secure At Work - Nested Group Membership Manager'
$form.Size = New-Object System.Drawing.Size(920, 925)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.MinimumSize = New-Object System.Drawing.Size(820, 745)
if ($script:AppIcon) { $form.Icon = $script:AppIcon }

# --- Header banner --------------------------------------------------------
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Location = New-Object System.Drawing.Point(0, 0)
$pnlHeader.Size = New-Object System.Drawing.Size(920, 88)
$pnlHeader.Anchor = 'Top,Left,Right'
$pnlHeader.BackColor = [System.Drawing.Color]::White

if ($script:LogoImage) {
    $picLogo = New-Object System.Windows.Forms.PictureBox
    $picLogo.Image = $script:LogoImage
    $picLogo.SizeMode = 'Zoom'
    $picLogo.Location = New-Object System.Drawing.Point(15, 10)
    $picLogo.Size = New-Object System.Drawing.Size(84, 66)
    $pnlHeader.Controls.Add($picLogo)
}

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = 'Nested Group Membership Manager'
$lblTitle.Location = New-Object System.Drawing.Point(112, 30)
$lblTitle.Size = New-Object System.Drawing.Size(600, 30)
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $script:BrandDark
$pnlHeader.Controls.Add($lblTitle)

$pnlHeaderAccent = New-Object System.Windows.Forms.Panel
$pnlHeaderAccent.Location = New-Object System.Drawing.Point(0, 85)
$pnlHeaderAccent.Size = New-Object System.Drawing.Size(920, 3)
$pnlHeaderAccent.Anchor = 'Top,Left,Right'
$pnlHeaderAccent.BackColor = $script:BrandPrimary
$pnlHeader.Controls.Add($pnlHeaderAccent)

# --- Sign-in note --------------------------------------------------------
$grpConnection = New-Object System.Windows.Forms.GroupBox
$grpConnection.Text = 'Sign-in'
$grpConnection.Location = New-Object System.Drawing.Point(12, 102)
$grpConnection.Size = New-Object System.Drawing.Size(880, 65)
$grpConnection.Anchor = 'Top,Left,Right'
$grpConnection.ForeColor = $script:BrandDark

$lblConnectHint = New-Object System.Windows.Forms.Label
$lblConnectHint.Text = 'Run below opens one new console window that signs in and executes together, then stays open for you to review -- close it yourself when done.'
$lblConnectHint.Location = New-Object System.Drawing.Point(15, 22)
$lblConnectHint.Size = New-Object System.Drawing.Size(850, 18)
$lblConnectHint.ForeColor = [System.Drawing.Color]::DimGray
$lblConnectHint.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)

$chkDeviceCode = New-Object System.Windows.Forms.CheckBox
$chkDeviceCode.Text = 'Use device code sign-in'
$chkDeviceCode.Location = New-Object System.Drawing.Point(15, 42)
$chkDeviceCode.Size = New-Object System.Drawing.Size(270, 20)

$btnConnect = New-Object System.Windows.Forms.Button
$btnConnect.Text = 'Connect...'
$btnConnect.Location = New-Object System.Drawing.Point(785, 20)
$btnConnect.Size = New-Object System.Drawing.Size(90, 30)
$btnConnect.Anchor = 'Top,Right'

$grpConnection.Controls.AddRange(@($lblConnectHint, $chkDeviceCode, $btnConnect))

# --- CSV panel ----------------------------------------------------------------
$grpCsv = New-Object System.Windows.Forms.GroupBox
$grpCsv.Text = 'Group membership CSV'
$grpCsv.Location = New-Object System.Drawing.Point(12, 175)
$grpCsv.Size = New-Object System.Drawing.Size(880, 55)
$grpCsv.Anchor = 'Top,Left,Right'
$grpCsv.ForeColor = $script:BrandDark

$txtCsvPath = New-Object System.Windows.Forms.TextBox
$txtCsvPath.Location = New-Object System.Drawing.Point(15, 22)
$txtCsvPath.Size = New-Object System.Drawing.Size(745, 22)
$txtCsvPath.Anchor = 'Top,Left,Right'
$defaultCsv = Join-Path $ScriptDirectory 'nested-group-membership.csv'
if (Test-Path $defaultCsv) { $txtCsvPath.Text = $defaultCsv }

$btnBrowseCsv = New-Object System.Windows.Forms.Button
$btnBrowseCsv.Text = 'Browse...'
$btnBrowseCsv.Location = New-Object System.Drawing.Point(770, 21)
$btnBrowseCsv.Size = New-Object System.Drawing.Size(100, 24)
$btnBrowseCsv.Anchor = 'Top,Right'

$grpCsv.Controls.AddRange(@($txtCsvPath, $btnBrowseCsv))

# --- Phase panel --------------------------------------------------------
$grpPhase = New-Object System.Windows.Forms.GroupBox
$grpPhase.Text = 'Deployment phase'
$grpPhase.Location = New-Object System.Drawing.Point(12, 236)
$grpPhase.Size = New-Object System.Drawing.Size(880, 55)
$grpPhase.Anchor = 'Top,Left,Right'
$grpPhase.ForeColor = $script:BrandDark

$rbPhaseAll = New-Object System.Windows.Forms.RadioButton
$rbPhaseAll.Text = 'All (no phase filtering)'
$rbPhaseAll.Location = New-Object System.Drawing.Point(15, 24)
$rbPhaseAll.Size = New-Object System.Drawing.Size(220, 20)
$rbPhaseAll.Checked = $true

$rbPhaseBuilding = New-Object System.Windows.Forms.RadioButton
$rbPhaseBuilding.Text = 'Building (customer still onboarding)'
$rbPhaseBuilding.Location = New-Object System.Drawing.Point(245, 24)
$rbPhaseBuilding.Size = New-Object System.Drawing.Size(280, 20)

$rbPhaseDone = New-Object System.Windows.Forms.RadioButton
$rbPhaseDone.Text = 'Done (customer fully rolled out)'
$rbPhaseDone.Location = New-Object System.Drawing.Point(535, 24)
$rbPhaseDone.Size = New-Object System.Drawing.Size(280, 20)

$grpPhase.Controls.AddRange(@($rbPhaseAll, $rbPhaseBuilding, $rbPhaseDone))

# --- Options panel --------------------------------------------------------
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Text = 'What to do'
$grpOptions.Location = New-Object System.Drawing.Point(12, 301)
$grpOptions.Size = New-Object System.Drawing.Size(880, 190)
$grpOptions.Anchor = 'Top,Left,Right'
$grpOptions.ForeColor = $script:BrandDark

$rbCheck = New-Object System.Windows.Forms.RadioButton
$rbCheck.Text = 'Check only (read-only audit -- makes no changes)'
$rbCheck.Location = New-Object System.Drawing.Point(15, 25)
$rbCheck.Size = New-Object System.Drawing.Size(500, 20)
$rbCheck.Checked = $true

$rbApply = New-Object System.Windows.Forms.RadioButton
$rbApply.Text = 'Apply (make changes)'
$rbApply.Location = New-Object System.Drawing.Point(15, 50)
$rbApply.Size = New-Object System.Drawing.Size(500, 20)

$chkCreate = New-Object System.Windows.Forms.CheckBox
$chkCreate.Text = 'Create missing groups'
$chkCreate.Location = New-Object System.Drawing.Point(40, 75)
$chkCreate.Size = New-Object System.Drawing.Size(400, 20)
$chkCreate.Enabled = $false

$chkRemove = New-Object System.Windows.Forms.CheckBox
$chkRemove.Text = 'Remove unexpected members (recognized groups, wrong parent)'
$chkRemove.Location = New-Object System.Drawing.Point(40, 100)
$chkRemove.Size = New-Object System.Drawing.Size(500, 20)
$chkRemove.Enabled = $false

$chkIncludeUnrecognized = New-Object System.Windows.Forms.CheckBox
$chkIncludeUnrecognized.Text = 'Also remove unrecognized objects (not confirmed to be one of our groups -- reviewed carefully first)'
$chkIncludeUnrecognized.Location = New-Object System.Drawing.Point(65, 123)
$chkIncludeUnrecognized.Size = New-Object System.Drawing.Size(700, 20)
$chkIncludeUnrecognized.Enabled = $false
$chkIncludeUnrecognized.ForeColor = [System.Drawing.Color]::Firebrick

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = 'Preview only (WhatIf) -- show what would happen without changing anything'
$chkWhatIf.Location = New-Object System.Drawing.Point(40, 150)
$chkWhatIf.Size = New-Object System.Drawing.Size(600, 20)
$chkWhatIf.Enabled = $false

$grpOptions.Controls.AddRange(@($rbCheck, $rbApply, $chkCreate, $chkRemove, $chkIncludeUnrecognized, $chkWhatIf))

# --- Report panel --------------------------------------------------------
$grpReport = New-Object System.Windows.Forms.GroupBox
$grpReport.Text = 'Report'
$grpReport.Location = New-Object System.Drawing.Point(12, 495)
$grpReport.Size = New-Object System.Drawing.Size(880, 55)
$grpReport.Anchor = 'Top,Left,Right'
$grpReport.ForeColor = $script:BrandDark

$chkReport = New-Object System.Windows.Forms.CheckBox
$chkReport.Text = 'Generate report:'
$chkReport.Location = New-Object System.Drawing.Point(15, 24)
$chkReport.Size = New-Object System.Drawing.Size(130, 20)
$chkReport.Checked = $true

$txtReportPath = New-Object System.Windows.Forms.TextBox
$txtReportPath.Location = New-Object System.Drawing.Point(150, 22)
$txtReportPath.Size = New-Object System.Drawing.Size(610, 22)
$txtReportPath.Anchor = 'Top,Left,Right'
$txtReportPath.Text = Join-Path $ScriptDirectory ("report_{0}.html" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$btnBrowseReport = New-Object System.Windows.Forms.Button
$btnBrowseReport.Text = 'Browse...'
$btnBrowseReport.Location = New-Object System.Drawing.Point(770, 21)
$btnBrowseReport.Size = New-Object System.Drawing.Size(100, 24)
$btnBrowseReport.Anchor = 'Top,Right'

$grpReport.Controls.AddRange(@($chkReport, $txtReportPath, $btnBrowseReport))

# --- Run / progress ---------------------------------------------------------
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run'
$btnRun.Location = New-Object System.Drawing.Point(12, 558)
$btnRun.Size = New-Object System.Drawing.Size(120, 34)
$btnRun.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$btnRun.BackColor = $script:BrandPrimary
$btnRun.ForeColor = [System.Drawing.Color]::White

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Cancel'
$btnCancel.Location = New-Object System.Drawing.Point(140, 558)
$btnCancel.Size = New-Object System.Drawing.Size(90, 34)
$btnCancel.Enabled = $false

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(240, 565)
$progress.Size = New-Object System.Drawing.Size(400, 20)
$progress.Style = 'Marquee'
$progress.Visible = $false
$progress.Anchor = 'Top,Left,Right'

$btnOpenReport = New-Object System.Windows.Forms.Button
$btnOpenReport.Text = 'Open Report'
$btnOpenReport.Location = New-Object System.Drawing.Point(780, 558)
$btnOpenReport.Size = New-Object System.Drawing.Size(112, 34)
$btnOpenReport.Anchor = 'Top,Right'
$btnOpenReport.Enabled = $false

# --- Log ----------------------------------------------------------------
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = 'Output'
$lblLog.Location = New-Object System.Drawing.Point(12, 600)
$lblLog.Size = New-Object System.Drawing.Size(200, 18)
$lblLog.Anchor = 'Top,Left'

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = New-Object System.Drawing.Point(12, 620)
$txtLog.Size = New-Object System.Drawing.Size(880, 255)
$txtLog.Anchor = 'Top,Bottom,Left,Right'
$txtLog.ReadOnly = $true
$txtLog.BackColor = [System.Drawing.Color]::White
$txtLog.Font = New-Object System.Drawing.Font('Cascadia Mono', 9)
if ($txtLog.Font.Name -ne 'Cascadia Mono') { $txtLog.Font = New-Object System.Drawing.Font('Consolas', 9) }

$form.Controls.AddRange(@(
    $pnlHeader,
    $grpConnection, $grpCsv, $grpPhase, $grpOptions, $grpReport,
    $btnRun, $btnCancel, $progress, $btnOpenReport,
    $lblLog, $txtLog
))

# =============================================================================
# Event handlers
# =============================================================================

$rbApply.Add_CheckedChanged({
    $chkCreate.Enabled = $rbApply.Checked
    $chkRemove.Enabled = $rbApply.Checked
    $chkWhatIf.Enabled = $rbApply.Checked
    if (-not $rbApply.Checked) {
        $chkIncludeUnrecognized.Enabled = $false
        $chkIncludeUnrecognized.Checked = $false
    }
    else {
        $chkIncludeUnrecognized.Enabled = $chkRemove.Checked
    }
})

$chkRemove.Add_CheckedChanged({
    $chkIncludeUnrecognized.Enabled = $chkRemove.Checked
    if (-not $chkRemove.Checked) { $chkIncludeUnrecognized.Checked = $false }
})

$chkReport.Add_CheckedChanged({
    $txtReportPath.Enabled = $chkReport.Checked
    $btnBrowseReport.Enabled = $chkReport.Checked
})

$btnBrowseCsv.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    $dlg.InitialDirectory = $ScriptDirectory
    if ($dlg.ShowDialog() -eq 'OK') { $txtCsvPath.Text = $dlg.FileName }
})

$btnBrowseReport.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'HTML report (*.html)|*.html|CSV report (*.csv)|*.csv'
    $dlg.InitialDirectory = $ScriptDirectory
    $dlg.FileName = Split-Path $txtReportPath.Text -Leaf
    if ($dlg.ShowDialog() -eq 'OK') { $txtReportPath.Text = $dlg.FileName }
})

function Start-ConsoleFallbackConnect {
    # The proven, always-works fallback: a separate console window, used
    # when the new in-process MSAL approach either isn't applicable
    # (device code) or throws for any reason.
    param([switch]$UseDeviceCode)

    $cmd = if ($UseDeviceCode) {
        "Connect-MgGraph -Scopes 'Group.Read.All' -NoWelcome -UseDeviceCode"
    }
    else {
        "Connect-MgGraph -Scopes 'Group.Read.All' -NoWelcome"
    }
    $cmd += @'

$__ctx = Get-MgContext
Write-Host ""
Write-Host ('=' * 64) -ForegroundColor Magenta
Write-Host " CONNECTED (preview only -- Run signs in again separately)" -ForegroundColor Magenta
Write-Host ('=' * 64) -ForegroundColor Magenta
Write-Host "  Tenant : $($__ctx.TenantId)" -ForegroundColor White
Write-Host "  Account: $($__ctx.Account)" -ForegroundColor White
Write-Host ('=' * 64) -ForegroundColor Magenta
Write-Host ""
Write-Host "Close this window whenever you like -- clicking Run opens its own separate window and signs in again from scratch." -ForegroundColor DarkGray
'@

    $proc = Start-ConsoleCommand -Command $cmd
    if ($proc) {
        Add-LogLine "Opened a preview sign-in window. This is just to show you the tenant -- it doesn't feed into Run." $script:ConsoleColorMap.Cyan
    }
}

$btnConnect.Add_Click({
    Start-ConsoleFallbackConnect -UseDeviceCode:$chkDeviceCode.Checked
})

# --- Run ------------------------------------------------------------------
# Opens one new console window that signs in AND runs the actual work
# together, in one continuous session -- the simple, proven-reliable
# approach. Output streams into the Output box below via a tailed
# transcript file; the window itself stays open afterward so it can also
# be reviewed directly if needed.
$script:lastReportPath = $null
$script:runProcess = $null
$script:runMarkerPath = $null
$script:runLogPath = $null
$script:runLogOffset = 0

$runPollTimer = New-Object System.Windows.Forms.Timer
$runPollTimer.Interval = 400

$runPollTimer.Add_Tick({
    if (-not $script:runProcess) { return }

    # Tail the transcript log every tick, independent of whether the run
    # has finished -- this mirrors the console window's live output into
    # this Output box. Uses Start-Transcript (writes to a file alongside
    # the real console) rather than redirecting the process's actual
    # output handle -- real redirection is exactly what silently breaks
    # the device-code prompt, whereas a transcript running alongside a
    # still-fully-attached console does not.
    if ($script:runLogPath -and (Test-Path $script:runLogPath)) {
        try {
            $stream = [System.IO.File]::Open($script:runLogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $stream.Seek($script:runLogOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader = New-Object System.IO.StreamReader($stream)
            $newText = $reader.ReadToEnd()
            $script:runLogOffset = $stream.Position
            $reader.Close()
            $stream.Close()

            if ($newText) {
                foreach ($line in ($newText -split "`r?`n")) {
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    $color = [System.Drawing.Color]::Black
                    if ($line -match '^WARNING:') { $color = $script:ConsoleColorMap.Yellow }
                    elseif ($line -match '^(ERROR|Exception|=== Script failed)') { $color = $script:ConsoleColorMap.Red }
                    elseif ($line -match '^(====|Connected|Resolved|Loaded|Fetching|Exported|Created group|Removed:|Signing in)') { $color = $script:ConsoleColorMap.Cyan }
                    Add-LogLine $line $color
                }
            }
        }
        catch {
            # Transcript file may be momentarily inaccessible right as it's
            # being written -- harmless, just catches up on the next tick.
        }
    }

    # Primary completion signal: the marker file the launched command
    # writes right after the actual script finishes, regardless of
    # whether the window itself then stays open (it does -- see
    # Start-ConsoleCommand's use of -NoExit).
    if ($script:runMarkerPath -and (Test-Path $script:runMarkerPath)) {
        $runPollTimer.Stop()
        $exitCode = 0
        try {
            $raw = (Get-Content -Path $script:runMarkerPath -Raw).Trim()
            [void][int]::TryParse($raw, [ref]$exitCode)
        }
        catch {}
        try { Remove-Item -Path $script:runMarkerPath -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-Item -Path $script:runLogPath -Force -ErrorAction SilentlyContinue } catch {}
        $script:runMarkerPath = $null
        $script:runLogPath = $null
        $script:runLogOffset = 0
        $script:runProcess = $null

        $progress.Visible = $false
        $btnRun.Enabled = $true
        $btnCancel.Enabled = $false

        if ($exitCode -eq 0) {
            Add-LogLine "`n=== Finished (exit code 0) ===" $script:ConsoleColorMap.Green
        }
        else {
            Add-LogLine "`n=== Finished (exit code $exitCode) -- see above; this can mean drift was found (normal for Check) or a real error, depending on what ran ===" $script:ConsoleColorMap.Yellow
        }

        if ($script:lastReportPath -and (Test-Path $script:lastReportPath)) {
            $btnOpenReport.Enabled = $true
        }

        [System.Windows.Forms.MessageBox]::Show(
            "Finished (exit code $exitCode). See the Output box above for the full transcript.",
            'Finished', 'OK', 'Information') | Out-Null
        return
    }

    # Fallback-of-the-fallback: the window closed (or crashed) before ever
    # writing the marker -- e.g. someone closed it manually.
    if ($script:runProcess.HasExited) {
        $runPollTimer.Stop()
        try { Remove-Item -Path $script:runLogPath -Force -ErrorAction SilentlyContinue } catch {}
        $script:runMarkerPath = $null
        $script:runLogPath = $null
        $script:runLogOffset = 0
        $script:runProcess = $null

        $progress.Visible = $false
        $btnRun.Enabled = $true
        $btnCancel.Enabled = $false

        Add-LogLine "The console window closed before finishing normally -- no result to report. Check whether it was closed manually." $script:ConsoleColorMap.Red
    }
})

$btnRun.Add_Click({
    if (-not (Test-Path $txtCsvPath.Text)) {
        [System.Windows.Forms.MessageBox]::Show('Pick a valid CSV file first.', 'Missing CSV', 'OK', 'Warning') | Out-Null
        return
    }

    $isApply = $rbApply.Checked
    $doRemove = $isApply -and $chkRemove.Checked -and -not $chkWhatIf.Checked

    if ($doRemove) {
        $target = if ($chkIncludeUnrecognized.Checked) { "recognized AND unrecognized" } else { "recognized" }
        $confirmResult = [System.Windows.Forms.MessageBox]::Show(
            "This will REMOVE unexpected group memberships ($target) from Entra ID. This cannot be undone from within this tool.`n`nAre you sure you want to continue?",
            'Confirm removal', 'YesNo', 'Warning', 'Button2')
        if ($confirmResult -ne 'Yes') { return }
    }

    $txtLog.Clear()
    $btnOpenReport.Enabled = $false
    $script:lastReportPath = $null

    $selectedPhase = if ($rbPhaseBuilding.Checked) { 'Building' } elseif ($rbPhaseDone.Checked) { 'Done' } else { 'All' }

    $scriptArgs = [System.Collections.Generic.List[string]]::new()
    $scriptArgs.Add("-CsvPath `"$($txtCsvPath.Text)`"")
    $scriptArgs.Add("-Phase $selectedPhase")
    if (-not $isApply) { $scriptArgs.Add("-Check") }
    $scriptArgs.Add("-Confirm:`$false")
    if ($isApply -and $chkCreate.Checked) { $scriptArgs.Add("-CreateMissingGroups") }
    if ($isApply -and $chkRemove.Checked) { $scriptArgs.Add("-RemoveUnexpectedMembers") }
    if ($isApply -and $chkRemove.Checked -and $chkIncludeUnrecognized.Checked) { $scriptArgs.Add("-IncludeUnrecognizedObjects") }
    if ($isApply -and $chkWhatIf.Checked) { $scriptArgs.Add("-WhatIf") }
    if ($chkReport.Checked -and $txtReportPath.Text) {
        $scriptArgs.Add("-ReportPath `"$($txtReportPath.Text)`"")
        $script:lastReportPath = $txtReportPath.Text
    }
    if ($chkDeviceCode.Checked) { $scriptArgs.Add("-DeviceCode") }

    $mainScriptPathEscaped = $mainScriptPath -replace "'", "''"
    $scriptInvocation = "& '$mainScriptPathEscaped' $($scriptArgs -join ' ')"

    $markerPath = Join-Path $env:TEMP ("NGM_done_{0}.txt" -f ([guid]::NewGuid().ToString('N')))
    $markerPathEscaped = $markerPath -replace "'", "''"
    $logPath = Join-Path $env:TEMP ("NGM_log_{0}.txt" -f ([guid]::NewGuid().ToString('N')))
    $logPathEscaped = $logPath -replace "'", "''"
    $fullCommand = @"
Start-Transcript -Path '$logPathEscaped' -Append | Out-Null
$scriptInvocation
`$__exitCode = if (`$null -ne `$LASTEXITCODE) { `$LASTEXITCODE } else { 0 }
Stop-Transcript | Out-Null
Set-Content -Path '$markerPathEscaped' -Value `$__exitCode
"@

    Add-LogLine "Opening a new console window to sign in and run $(if ($isApply) {'Apply'} else {'Check'})..." $script:ConsoleColorMap.Cyan

    $script:runProcess = Start-ConsoleCommand -Command $fullCommand
    if (-not $script:runProcess) {
        return
    }
    $script:runMarkerPath = $markerPath
    $script:runLogPath = $logPath
    $script:runLogOffset = 0

    $btnRun.Enabled = $false
    $btnCancel.Enabled = $true
    $progress.Visible = $true

    $runPollTimer.Start()
})

$btnCancel.Add_Click({
    if ($script:runProcess -and -not $script:runProcess.HasExited) {
        Add-LogLine "Stopping the console window running this..." $script:ConsoleColorMap.Yellow
        try { $script:runProcess.Kill() } catch {}
    }
})

$btnOpenReport.Add_Click({
    if ($script:lastReportPath -and (Test-Path $script:lastReportPath)) {
        Start-Process $script:lastReportPath
    }
})

$form.Add_FormClosing({
    if ($runPollTimer) {
        try { $runPollTimer.Stop() } catch {}
    }
    # Deliberately does NOT close $script:runProcess -- if a run is still
    # in progress in that separate window, closing this one shouldn't
    # yank it away.
})

$form.Add_Shown({
    # Belt-and-braces alongside the DPI fix above: forces every control to
    # repaint once the window is actually visible, in case anything (like
    # the Connect button) still didn't paint on the very first show.
    $form.Refresh()
})

[void]$form.ShowDialog()
