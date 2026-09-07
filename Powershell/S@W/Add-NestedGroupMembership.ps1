<#
.SYNOPSIS
    Reconciles or audits nested Entra ID security group memberships from a CSV file.

.DESCRIPTION
    Reads a ParentGroup,MemberGroup CSV describing the intended nesting and
    compares it against the live state in Entra ID.

    Two modes:
      - Apply (default): adds any missing nested memberships. Idempotent —
        relationships that already exist are skipped, so it's safe to
        re-run after every automation push that (re)creates the groups
        without their nesting. Also flags (Write-Warning, never acts on
        unless you explicitly opt in — see -RemoveUnexpectedMembers) any
        member found that isn't in the CSV for that parent — whether it's
        one of our own recognized/baseline groups nested under the wrong
        parent, or a group/object we don't recognize at all.
      - Check (-Check): read-only audit. Reports which relationships are
        already correct, which are missing, and the same unexpected/
        unrecognized members Apply mode flags. Makes no changes — ever,
        regardless of any other flag passed alongside -Check. Exits with
        code 1 if any drift is found, 0 if the tenant matches the CSV
        exactly — handy for a scheduled check or a CI pipeline step.

    Both modes use the same detection logic (Get-DriftFindings) for
    unexpected members, so what gets flagged doesn't depend on which mode
    you happened to run — a stray or unauthorized nested group shows up
    whether you're doing a routine apply run or an explicit audit.

    Before doing anything else (unless -SkipPreflight is used), the script
    checks the PowerShell edition, verifies the required modules are
    installed at a known-good version, and — after signing in — makes one
    cheap test call to prove the token actually works. This exists because
    Connect-MgGraph can report success while leaving you with an unusable
    token (see msgraph-sdk-powershell#3495), which otherwise only surfaces
    later as a wall of misleading "not found" results. Recommended to leave
    this on, especially the first time you run against a new customer
    tenant or machine.

    SAFETY POSTURE: by default, this script only ever ADDS — nested
    memberships (Apply mode) and, with -CreateMissingGroups, missing groups.
    -Check mode never writes anything, period, regardless of what else is
    passed alongside it. Removal is possible, but only via the explicit,
    separately-gated -RemoveUnexpectedMembers (and, further, its own
    -IncludeUnrecognizedObjects sub-option) — see those parameters' help for
    exactly what that does and doesn't cover, and note that every individual
    removal still requires its own confirmation on top of passing those
    flags. Outside of that one explicit path, there is no code anywhere in
    this script that removes a member or deletes a group.

    Requires the Microsoft.Graph.Groups module and delegated or app-only
    permission GroupMember.ReadWrite.All (Group.Read.All is enough for
    -Check, since it never writes). -CreateMissingGroups needs the broader
    Group.ReadWrite.All instead (GroupMember.ReadWrite.All only covers
    membership changes, not creating groups themselves) — the script
    requests the right scope automatically based on which flags you pass.

.PARAMETER CsvPath
    Path to the CSV file with columns: ParentGroup,MemberGroup

.PARAMETER GroupPrefix
    Prefix used to pull the relevant groups from Entra ID in one call instead
    of one Get-MgGroup per name. Defaults to 'AAD_' to match this naming
    convention. Adjust if your groups don't share a common prefix.

.PARAMETER Phase
    Filters which CSV rows this run applies to, based on an optional Phase
    column in the CSV (values: Building, Done, or blank/Both -- a row with
    no Phase value, or 'Both', always applies regardless of this parameter).

    Some relationships are only supposed to exist once a customer tenant is
    fully rolled out, not while it's still being built -- a dynamic device
    group with real enrolled devices, for example, that shouldn't be
    expected (or auto-created) while a customer is still onboarding their
    first few test devices. Tag those rows Phase=Done in the CSV. Rows that
    should hold from day one either get Phase=Building or are left blank.

    - All (default): no filtering -- every row applies, exactly like before
      this parameter existed. Safe default; existing automation that
      doesn't pass -Phase behaves exactly as it always has.
    - Building: only rows tagged Building or Both/blank apply. Rows tagged
      Done are excluded entirely -- not reported as missing, not created,
      not expected in any way.
    - Done: only rows tagged Done or Both/blank apply. Rows tagged Building
      that were relevant only during initial rollout are excluded.

.PARAMETER Check
    Read-only audit mode. No memberships are added or removed.

.PARAMETER DeviceCode
    Authenticate with device code flow instead of the interactive browser
    popup. Use this if Connect-MgGraph fails with "InteractiveBrowserCredential
    authentication failed: A window handle must be configured" — that happens
    when WAM (the default broker) has no parent window to attach to, which is
    common in embedded/hosted terminals (e.g. VS Code's integrated terminal).
    Running from a plain PowerShell/Windows Terminal window instead usually
    also fixes it, without needing this switch.

.PARAMETER ReportPath
    Optional, works in both modes. Writes the findings to this path — the
    format is auto-detected from the extension: .html/.htm produces a
    self-contained, color-coded HTML report grouped by parent group (problem
    groups expanded, clean ones collapsed); anything else produces a flat
    CSV. Under -Check, the report covers every CSV row (OK/Missing/etc.)
    plus unexpected members. Under Apply mode, it covers only the unexpected
    members flagged after adding what was missing (there's no "OK" list in
    apply mode — rows that were already fine or just got added aren't drift).

.PARAMETER SkipPreflight
    Skip the environment checks (PowerShell edition, module versions, and a
    live test call right after sign-in). Useful once you've verified a given
    machine/tenant combo is healthy and want a faster run. Not recommended
    the first time you run this against a new customer tenant/machine.

.PARAMETER CreateMissingGroups
    Apply mode only (ignored under -Check, which never writes to Entra ID —
    see the safety guarantee below). Creates any group referenced in the CSV,
    as either ParentGroup or MemberGroup, that doesn't already exist in the
    target tenant: an empty, static Security group (not mail-enabled, not a
    Microsoft 365 group, not dynamic), using the CSV name as both the display
    name and mail nickname. Created groups are then eligible for nesting in
    the same run. Off by default — a missing group is reported and skipped
    (MissingParent/MissingMember) rather than created, unless you opt in.
    Combine with Export-NestedGroupMembership.ps1 to stand up a customer
    tenant's entire group structure from a reference tenant's CSV in one
    pass — both the groups themselves and their nesting.

    By default, -CreateMissingGroups only ever ADDS groups and ADDS
    memberships, same as the rest of this script — see the removal
    parameters below (-RemoveUnexpectedMembers, -IncludeUnrecognizedObjects)
    for the one explicit, opt-in path that can remove something, and the
    top-level SAFETY POSTURE note above for how that fits together.

.PARAMETER RemoveUnexpectedMembers
    Apply mode only (ignored under -Check). Actually removes the "unexpected
    member" findings this script otherwise only flags: members that ARE part
    of the -GroupPrefix baseline, just nested under a parent the CSV doesn't
    say they should be under. Off by default. Every removal still goes
    through its own confirmation prompt (see below) even when this switch is
    on — it does not bypass that. Does NOT touch members flagged
    'ExtraUnknownObject' (objects this script can't identify as one of its
    own tracked groups) — add -IncludeUnrecognizedObjects for those too.

.PARAMETER IncludeUnrecognizedObjects
    Only meaningful together with -RemoveUnexpectedMembers. Extends removal
    to 'ExtraUnknownObject' findings too — members that aren't one of the
    -GroupPrefix groups at all, so this script has no way to confirm what
    they actually are (could be a user, device, service principal, or a
    group outside the naming convention entirely). This is real removal of
    something the script cannot identify, based only on "it wasn't in the
    CSV" — review the flagged list carefully before turning this on rather
    than assuming everything unrecognized is safe to remove.

    IMPORTANT ON REMOVAL SAFETY: -RemoveUnexpectedMembers and
    -IncludeUnrecognizedObjects are the ONLY things in this entire script
    that can remove anything, and both are off by default. Even with them
    on, each individual removal requires its own explicit confirmation
    (ConfirmImpact is set to High for this action specifically, so
    PowerShell prompts per item by default regardless of -Confirm) unless
    you pass -Confirm:$false or -WhatIf. Nothing else in this script — not
    -Check, not normal Apply mode, not -CreateMissingGroups — removes
    anything, ever.

.PARAMETER Force
    Skips two interactive safety prompts, for scheduled tasks / CI where
    there's no one to answer them: (1) the "you're already connected --
    use this connection?" banner, which only fires when a connection
    already existed before this run started, and (2) the "about to apply
    changes to this tenant, proceed?" confirmation that otherwise always
    shows before Apply mode does anything (skipped automatically under
    -WhatIf too, since nothing happens there either way). Not recommended
    for interactive use -- these exist specifically to catch a wrong
    tenant before you act on it.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Check

    Audits current state against the CSV, prints a report, changes nothing.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Phase Building -Check

    Audits only against rows that apply while a customer tenant is still
    being built (Phase=Building or blank/Both in the CSV) -- relationships
    that are only expected once the customer is fully rolled out
    (Phase=Done) are left out of the check entirely, not reported as missing.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Phase Done -CreateMissingGroups

    Once a customer is fully onboarded, switch to Phase=Done to also create/
    nest the relationships that only apply once rollout is complete.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Check -ReportPath .\drift-report.html

    Same audit, also saves a color-coded HTML report — open it in a browser,
    grouped by parent group, problem groups expanded automatically.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Check -ReportPath .\drift-report.csv

    Same audit, saves the findings as a flat CSV instead (for diffing over
    time, or feeding into something else).

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Check -DeviceCode

    Audits with device code sign-in instead of the browser popup — use this
    if Connect-MgGraph fails with a "window handle must be configured" error
    (common in embedded/hosted terminals).

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -WhatIf

    Dry run of apply mode: shows what would be added without changing anything.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv

    Actually applies the missing memberships.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -CreateMissingGroups -WhatIf

    Dry run showing which groups would be created AND which memberships would
    be added — the full picture for standing up a brand-new customer tenant
    from a reference tenant's exported CSV, without changing anything yet.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -CreateMissingGroups

    Creates any missing groups as empty Security groups, then nests them —
    turns a CSV exported from a reference tenant into a fully working group
    structure on a tenant that has none of these groups yet.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Check -SkipPreflight

    Skips the module/version/token checks — use only once you've confirmed
    this machine and tenant are already healthy (e.g. repeated runs in the
    same session, or a scheduled task where you've already validated the
    setup once).

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -Check -Force

    Skips the "already connected — use this connection?" prompt too. For a
    scheduled task, not for switching between customer tenants by hand.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -RemoveUnexpectedMembers -WhatIf

    Dry run showing exactly which unexpected members would be removed —
    only the ones that ARE recognized baseline groups, just under the wrong
    parent. Nothing is changed; review the list before dropping -WhatIf.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -RemoveUnexpectedMembers

    Removes recognized-but-misplaced members after their normal flagging.
    Each one still prompts individually for confirmation unless you also
    pass -Confirm:$false. Members this script can't identify at all
    ('ExtraUnknownObject') are left alone even here — see the next example.

.EXAMPLE
    .\Add-NestedGroupMembership.ps1 -CsvPath .\nested-group-membership.csv -RemoveUnexpectedMembers -IncludeUnrecognizedObjects -WhatIf

    Same, but also previews removing members this script can't identify as
    one of its own groups at all (could be a user, device, or service
    principal) — review this list especially carefully before dropping
    -WhatIf, since "unrecognized" isn't the same as "safe to remove".
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$GroupPrefix = 'AAD_',

    [ValidateSet('All', 'Building', 'Done')]
    [string]$Phase = 'All',

    [switch]$Check,

    [string]$ReportPath,

    [switch]$DeviceCode,

    [switch]$SkipPreflight,

    [switch]$CreateMissingGroups,

    [switch]$RemoveUnexpectedMembers,

    [switch]$IncludeUnrecognizedObjects,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Everything below runs inside a top-level try/catch so that ANY failure --
# not just the ones this script explicitly anticipates -- reports exactly
# where it happened. PowerShell 7's default error view hides the "At line X"
# location by default, which is why identical-looking errors can otherwise
# give no clue where they came from.
try {

# Minimum Microsoft.Graph.Authentication version known to include the fix for
# msgraph-sdk-powershell#3495 (device-code token not cached correctly, causing
# every call after a successful sign-in to fail with "Object reference not set
# to an instance of an object."). Fix merged 2026-04-03; 2.38.0 (2026-06-16)
# confirmed to include it. Kept conservative since the exact first patched
# release wasn't published.
$script:MinGraphModuleVersion = [version]'2.36.0'

# --- Preflight ---------------------------------------------------------------
function Test-ScriptPreflight {
    [CmdletBinding()]
    param()

    $blocking = [System.Collections.Generic.List[string]]::new()
    $requiredModules = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Groups'
    $highestVersion = @{}   # ModuleName -> highest version installed

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Write-Warning "Running on Windows PowerShell $($PSVersionTable.PSVersion) (Desktop edition). PowerShell 7+ (pwsh) is recommended -- several Microsoft Graph SDK auth bugs (WAM window-handle errors, device-code failures) are specific to the legacy console host."
    }

    foreach ($moduleName in $requiredModules) {
        $allInstalled = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending

        if (-not $allInstalled) {
            $blocking.Add("Required module '$moduleName' isn't installed. Install it with: Install-Module $moduleName -Scope CurrentUser -Force")
            continue
        }

        $highest = $allInstalled[0]
        $highestVersion[$moduleName] = $highest.Version

        if ($allInstalled.Count -gt 1) {
            $allVersionsList = ($allInstalled.Version -join ', ')
            Write-Warning "$moduleName has $($allInstalled.Count) versions installed side by side ($allVersionsList). PowerShell should auto-load the highest, but a stale one can still end up loaded -- see the version-mismatch check below if auth keeps failing."
        }

        if ($highest.Version -lt $script:MinGraphModuleVersion) {
            Write-Warning "$moduleName is version $($highest.Version) -- $($script:MinGraphModuleVersion)+ is recommended. Older versions have known auth bugs (e.g. msgraph-sdk-powershell#3495, #2798)."
        }

        $loaded = Get-Module -Name $moduleName   # already imported into THIS session, if any
        if ($loaded -and $loaded.Version -lt $highest.Version) {
            Write-Warning "$moduleName $($loaded.Version) is already loaded in this session even though $($highest.Version) is installed. Open a NEW PowerShell window so the newer version actually gets used."
        }
    }

    # The individual per-module checks above can each pass while the modules
    # still don't match each other -- and a mismatch across Microsoft.Graph.*
    # modules is a well-documented cause of exactly this kind of auth failure
    # (a module built against an older Authentication version can force that
    # older version to load as its dependency). This is the check that would
    # have caught today's failure: Authentication looked new enough on its
    # own, but Groups was still on 2.34.0.
    if ($blocking.Count -eq 0) {
        $distinctVersions = $highestVersion.Values | Sort-Object -Unique
        if ($distinctVersions.Count -gt 1) {
            $summary = ($highestVersion.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join ', '
            Write-Warning "Microsoft.Graph module versions don't match ($summary). Mixed versions are a common, well-documented cause of failures like 'DeviceCodeCredential authentication failed: Object reference not set...' -- even when each module individually looks new enough. Fix by removing ALL versions of both and reinstalling fresh so they match:"
            Write-Warning "    Uninstall-Module Microsoft.Graph.Groups -AllVersions -Force"
            Write-Warning "    Uninstall-Module Microsoft.Graph.Authentication -AllVersions -Force"
            Write-Warning "    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force"
            Write-Warning "    Install-Module Microsoft.Graph.Groups -Scope CurrentUser -Force"
            Write-Warning "    (then open a NEW PowerShell window before running this script again)"
        }
    }

    if ($blocking.Count -gt 0) {
        $blocking | ForEach-Object { Write-Warning $_ }
        throw "Preflight failed: $($blocking.Count) required module(s) missing. See warnings above."
    }
}

if (-not $SkipPreflight) {
    Test-ScriptPreflight
}

# --- Check for an existing connection before doing anything else -----------
# A leftover connection from a previous script run against a DIFFERENT
# tenant is the single easiest way to make changes in the wrong place
# without noticing. Surface it and let the person decide, rather than
# silently reusing whatever happens to already be connected.
if (-not $Force -and (Get-MgContext)) {
    $ctx = Get-MgContext
    $bannerWidth = 64
    Write-Host ""
    Write-Host ('=' * $bannerWidth) -ForegroundColor Magenta
    Write-Host " ALREADY CONNECTED TO MICROSOFT GRAPH" -ForegroundColor Magenta -BackgroundColor Black
    Write-Host ('=' * $bannerWidth) -ForegroundColor Magenta
    Write-Host "  Tenant : $($ctx.TenantId)" -ForegroundColor White
    Write-Host "  Account: $($ctx.Account)" -ForegroundColor White
    Write-Host "  Scopes : $($ctx.Scopes -join ', ')" -ForegroundColor DarkGray
    Write-Host ('=' * $bannerWidth) -ForegroundColor Magenta

    $answer = Read-Host "`nUse this connection? [Y] Yes (default)  [N] No, disconnect and sign in again"
    if ($answer -match '^n') {
        Write-Host "Disconnecting..." -ForegroundColor Cyan
        Disconnect-MgGraph | Out-Null
    }
    else {
        Write-Host "Continuing with the existing connection." -ForegroundColor Cyan
    }
}

# --- Connect ---------------------------------------------------------------
if (-not (Get-MgContext)) {
    $scopes =
        if ($Check) { 'Group.Read.All' }
        elseif ($CreateMissingGroups) { 'Group.ReadWrite.All' }   # superset: covers both group creation and membership changes
        else { 'GroupMember.ReadWrite.All', 'Group.Read.All' }    # least privilege: membership changes only, cannot create/modify/delete groups
    $connectParams = @{ Scopes = $scopes; NoWelcome = $true }
    if ($DeviceCode) { $connectParams['UseDeviceCode'] = $true }

    try {
        if ($DeviceCode) {
            # Do NOT pipe/capture this call — the SDK only prints the
            # "go to microsoft.com/devicelogin and enter code XXXX" prompt
            # to the console when its output isn't redirected. Piping it to
            # Out-Null hides the code and the sign-in silently times out
            # after 120s. See: github.com/microsoftgraph/msgraph-sdk-powershell/issues/2798
            Connect-MgGraph @connectParams
        }
        else {
            Connect-MgGraph @connectParams | Out-Null
        }
    }
    catch {
        if ($_.Exception.Message -match 'window handle') {
            Write-Warning "Interactive browser sign-in failed (no parent window handle available in this terminal)."
            Write-Warning "Re-run with -DeviceCode, or run this script from a plain PowerShell/Windows Terminal window instead."
        }
        throw
    }
}

# Sign-in succeeding doesn't guarantee the token actually works (see
# msgraph-sdk-powershell#3495: -DeviceCode on older module versions signs in
# fine, then every real API call fails). Prove the token works with a cheap
# call before doing anything else, so a broken token fails loudly here instead
# of silently turning into a wall of false "not found" results later.
if (-not $SkipPreflight) {
    try {
        $null = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=id&$top=1'
    }
    catch {
        Write-Warning "Signed in, but a test Graph call failed: $($_.Exception.Message)"
        Write-Warning "This is almost always msgraph-sdk-powershell#3495 -- the sign-in token isn't actually usable yet. Most often this is a MISMATCH between your Microsoft.Graph.Authentication and Microsoft.Graph.Groups versions (see the preflight warnings above, or re-run without -SkipPreflight to see them). Uninstall ALL versions of both and reinstall fresh so they match, open a NEW terminal, and try again. Or drop -DeviceCode and sign in interactively instead."
        throw
    }
}

# --- Apply-mode confirmation gate ---------------------------------------------
# Distinct from the "already connected?" banner above: that one only fires
# when a connection already existed BEFORE this run started, which rarely
# happens for a freshly launched process/window (there's usually nothing
# yet to confirm) -- so it can't be relied on as the only safety check
# before real changes happen. This one always shows for Apply mode,
# whether the connection is fresh or reused, right before anything
# destructive or creative can occur. Skipped for -WhatIf (nothing will
# actually happen) and -Force (consistent with -Force meaning "skip
# interactive safety prompts," for unattended/scheduled runs).
if (-not $Check -and -not $Force -and -not $WhatIfPreference) {
    $ctx = Get-MgContext
    $bannerWidth = 64
    Write-Host ""
    Write-Host ('=' * $bannerWidth) -ForegroundColor Magenta
    Write-Host " ABOUT TO APPLY CHANGES" -ForegroundColor Magenta -BackgroundColor Black
    Write-Host ('=' * $bannerWidth) -ForegroundColor Magenta
    Write-Host "  Tenant : $($ctx.TenantId)" -ForegroundColor White
    Write-Host "  Account: $($ctx.Account)" -ForegroundColor White
    Write-Host ('=' * $bannerWidth) -ForegroundColor Magenta

    $applyConfirm = Read-Host "`nProceed with changes to this tenant? [Y] Yes  [N] No, abort (default)"
    if ($applyConfirm -notmatch '^y') {
        Write-Host "Aborted -- no changes made." -ForegroundColor Yellow
        exit 1
    }
}

# --- Load desired state ------------------------------------------------------
if (-not (Test-Path $CsvPath)) {
    throw "CSV not found: $CsvPath"
}
$rows = Import-Csv -Path $CsvPath
if (-not $rows) { throw "No rows found in $CsvPath" }

# Guard against blank cells before anything downstream calls .Trim() on them --
# a row missing ParentGroup or MemberGroup comes back as $null from Import-Csv
# (not an empty string), and .Trim() on $null throws "You cannot call a method
# on a null-valued expression." Catch it here with a clear message instead.
$invalidRows = $rows | Where-Object {
    [string]::IsNullOrWhiteSpace($_.ParentGroup) -or [string]::IsNullOrWhiteSpace($_.MemberGroup)
}
if ($invalidRows) {
    Write-Warning "$($invalidRows.Count) row(s) in the CSV have a blank ParentGroup or MemberGroup and will be skipped:"
    $invalidRows | ForEach-Object { Write-Warning "    ParentGroup='$($_.ParentGroup)' MemberGroup='$($_.MemberGroup)'" }
    $rows = $rows | Where-Object {
        -not ([string]::IsNullOrWhiteSpace($_.ParentGroup) -or [string]::IsNullOrWhiteSpace($_.MemberGroup))
    }
    if (-not $rows) { throw "No valid rows remain in $CsvPath after skipping blank entries." }
}

# Warn about typos in the optional Phase column before filtering on it --
# without this, a row like Phase='Buildign' would silently match NEITHER
# -Phase Building nor -Phase Done and just vanish from every run.
$recognizedPhaseTags = 'Building', 'Done', 'Both'
$unrecognizedPhaseTags = @($rows | Where-Object { $_.Phase -and $_.Phase -notin $recognizedPhaseTags } | Select-Object -ExpandProperty Phase -Unique)
if ($unrecognizedPhaseTags) {
    Write-Warning "CSV has row(s) with an unrecognized Phase value: $($unrecognizedPhaseTags -join ', '). Expected 'Building', 'Done', 'Both', or blank. These rows won't match -Phase Building or -Phase Done until fixed (they still apply under -Phase All)."
}

if ($Phase -ne 'All') {
    $beforePhaseFilter = $rows.Count
    $rows = $rows | Where-Object {
        [string]::IsNullOrWhiteSpace($_.Phase) -or $_.Phase -eq 'Both' -or $_.Phase -eq $Phase
    }
    $excludedByPhase = $beforePhaseFilter - $rows.Count
    if ($excludedByPhase -gt 0) {
        Write-Host "Excluded $excludedByPhase row(s) not applicable to phase '$Phase' (tagged for the other phase)." -ForegroundColor DarkGray
    }
    if (-not $rows) { throw "No rows apply to -Phase $Phase after filtering. Check the CSV's Phase column values." }
}

# Dedupe in case the CSV has repeats
$rows = $rows | Sort-Object ParentGroup, MemberGroup -Unique

Write-Host "Loaded $($rows.Count) desired nested-membership relationship(s) from $CsvPath (phase: $Phase)" -ForegroundColor Cyan

# --- Resolve all involved group names to object IDs in one call ------------
Write-Host "Fetching groups matching prefix '$GroupPrefix' from Entra ID..." -ForegroundColor Cyan
$allGroups = Get-MgGroup -Filter "startswith(displayName,'$GroupPrefix')" -All -Property Id, DisplayName

$groupMap = @{}   # DisplayName -> Id
$idToName = @{}   # Id -> DisplayName (reverse lookup, for reporting unexpected members)
foreach ($g in $allGroups) {
    $groupMap[$g.DisplayName] = $g.Id
    $idToName[$g.Id] = $g.DisplayName
}
Write-Host "Resolved $($groupMap.Count) groups." -ForegroundColor Cyan

$willCreateMissing = $CreateMissingGroups -and -not $Check
if ($groupMap.Count -eq 0 -and -not $willCreateMissing) {
    throw "No groups matching prefix '$GroupPrefix' were found in this tenant. Before assuming the groups are missing, double-check: (1) you're signed into the intended tenant (Get-MgContext), (2) -GroupPrefix matches your naming convention, and (3) the sign-in token actually works (re-run without -SkipPreflight). Stopping here rather than reporting every relationship as missing. If this tenant genuinely has none of these groups yet, re-run with -CreateMissingGroups to create them."
}

if ($CreateMissingGroups -and $Check) {
    Write-Warning "-CreateMissingGroups is ignored under -Check -- Check mode never writes to Entra ID, by design. Run without -Check to actually create anything."
}

if ($RemoveUnexpectedMembers -and $Check) {
    Write-Warning "-RemoveUnexpectedMembers is ignored under -Check -- Check mode never writes to Entra ID, by design. Run without -Check to actually remove anything."
}

# --- Create missing groups (opt-in, apply mode only) --------------------------
# SAFETY: this block only ever calls New-MgGroup. It never calls Remove-MgGroup
# or anything else destructive -- see the safety guarantee in the script help.
$groupsCreated = 0
if ($willCreateMissing) {
    $allNamesInCsv = @($rows.ParentGroup) + @($rows.MemberGroup) | Sort-Object -Unique
    $missingNames = $allNamesInCsv | Where-Object { -not $groupMap.ContainsKey($_) }

    if ($missingNames) {
        Write-Host "Creating $($missingNames.Count) missing group(s) as empty static Security groups..." -ForegroundColor Cyan
        foreach ($name in $missingNames) {
            if ($PSCmdlet.ShouldProcess($name, 'Create Security group')) {
                try {
                    # mailNickname must not contain spaces or most punctuation;
                    # this naming convention (letters/digits/hyphen/underscore)
                    # already fits, but sanitize defensively in case a CSV name
                    # doesn't.
                    $nickname = ($name -replace '[^A-Za-z0-9_-]', '_')
                    if ($nickname.Length -gt 64) { $nickname = $nickname.Substring(0, 64) }

                    $newGroup = New-MgGroup -DisplayName $name -MailEnabled:$false -MailNickname $nickname -SecurityEnabled:$true -GroupTypes @()
                    $groupMap[$name] = $newGroup.Id
                    $idToName[$newGroup.Id] = $name
                    Write-Host "Created group: $name" -ForegroundColor Green
                    $groupsCreated++
                }
                catch {
                    Write-Warning "Failed to create group '$name': $($_.Exception.Message)"
                }
            }
        }
    }
    else {
        Write-Host "No missing groups to create -- all $($allNamesInCsv.Count) group(s) referenced in the CSV already exist." -ForegroundColor Cyan
    }
}

# --- Cache existing members per parent group so we only call Graph once per parent ---
$existingMembersByParent = @{}
function Get-ExistingMemberIds {
    param([string]$ParentId)
    if (-not $existingMembersByParent.ContainsKey($ParentId)) {
        $members = @(Get-MgGroupMember -GroupId $ParentId -All -ErrorAction Stop)
        # @(...) forces a real (possibly empty) array instead of $null when a
        # group has zero members. Passing $null straight into
        # HashSet[string]::new() throws "Multiple ambiguous overloads found
        # for 'new' and the argument count: '1'" -- .NET can't tell whether
        # $null was meant as the IEnumerable<T> constructor or the
        # IEqualityComparer<T> one. An empty typed array has no such ambiguity.
        $memberIds = [string[]]@($members | Select-Object -ExpandProperty Id)
        $existingMembersByParent[$ParentId] = [System.Collections.Generic.HashSet[string]]::new($memberIds)
    }
    $result = $existingMembersByParent[$ParentId]
    if (-not $result) {
        # Defensive guarantee: never hand back $null, no matter what. If this
        # ever triggers it means the cache populated with something falsy --
        # treat it as "no known members yet" rather than crash every caller.
        $result = [System.Collections.Generic.HashSet[string]]::new()
        $existingMembersByParent[$ParentId] = $result
    }
    # The leading comma is load-bearing, not decorative: PowerShell
    # auto-enumerates any collection written to a function's output stream.
    # "return $result" for an empty HashSet outputs *zero* pipeline objects
    # (not one empty HashSet), which is exactly what made $existing end up
    # $null for any group with no current members -- the most common case
    # for a freshly created group. ",$result" wraps it in a 1-element array
    # so exactly one object -- the HashSet itself -- comes out the other end.
    return ,$result
}

# Expected relationships per parent, built once and shared by both modes:
# Check mode reports drift as part of its audit; Apply mode uses the same
# function to flag it too (see below) so unexpected/unrecognized members
# aren't only visible when someone happens to run -Check.
$expectedByParent = @{}
foreach ($row in $rows) {
    $p = $row.ParentGroup.Trim()
    if (-not $expectedByParent.ContainsKey($p)) { $expectedByParent[$p] = [System.Collections.Generic.HashSet[string]]::new() }
    $expectedByParent[$p].Add($row.MemberGroup.Trim()) | Out-Null
}

# For every parent group that exists and is in the CSV, find members present
# in Entra ID that are NOT in the CSV -- whether that member IS one of our
# own recognized/baseline groups (just not expected under THIS parent) or a
# group we don't recognize at all. Both are reported ('Extra' vs
# 'ExtraUnknownObject') and NEVER acted on: this function only ever reads
# (Get-MgGroupMember, via Get-ExistingMemberIds) and returns findings. It
# has no code path that removes a member or deletes a group.
function Get-DriftFindings {
    [CmdletBinding()]
    param(
        [hashtable]$ExpectedByParent,
        [hashtable]$GroupMap,
        [hashtable]$IdToName
    )

    $drift = [System.Collections.Generic.List[object]]::new()

    foreach ($parentName in $ExpectedByParent.Keys) {
        $parentId = $GroupMap[$parentName]
        if (-not $parentId) { continue }  # parent itself missing -- reported separately by the caller

        $existing = Get-ExistingMemberIds -ParentId $parentId
        $expectedNames = $ExpectedByParent[$parentName]

        foreach ($memberId in $existing) {
            $memberName = $IdToName[$memberId]
            if (-not $memberName) {
                # Not a group matching -GroupPrefix at all -- could be a
                # stray user/device, or a group entirely outside our naming
                # convention. Unrecognized, but flagged, not removed unless
                # -RemoveUnexpectedMembers -IncludeUnrecognizedObjects is used.
                $drift.Add([pscustomobject]@{ ParentGroup = $parentName; ParentId = $parentId; MemberGroup = "(unresolved object: $memberId)"; MemberId = $memberId; Status = 'ExtraUnknownObject' })
                continue
            }
            if (-not $expectedNames.Contains($memberName)) {
                # A group we DO recognize (part of the -GroupPrefix baseline)
                # but not expected as a child of this specific parent per the
                # CSV. Flagged, not removed unless -RemoveUnexpectedMembers.
                $drift.Add([pscustomobject]@{ ParentGroup = $parentName; ParentId = $parentId; MemberGroup = $memberName; MemberId = $memberId; Status = 'Extra' })
            }
        }
    }

    # Same collection-unrolling trap as Get-ExistingMemberIds: an empty List
    # returned bare comes out as zero pipeline objects, turning "no drift
    # found" into $null instead of an empty list. The comma prevents that.
    return ,$drift
}

# --- Removal (opt-in, apply mode only) ----------------------------------------
# The ONLY function in this script that can remove anything. ConfirmImpact
# 'High' is deliberate and separate from the rest of the script: PowerShell's
# default $ConfirmPreference is 'High', which means THIS specific action
# prompts for confirmation per item automatically, even without -Confirm,
# unless the caller explicitly passes -Confirm:$false or -WhatIf. Every other
# ShouldProcess call in this script (adding memberships, creating groups)
# stays at the default Medium impact and does not auto-prompt this way.
function Remove-UnexpectedGroupMember {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$ParentId,
        [Parameter(Mandatory)][string]$ParentName,
        [Parameter(Mandatory)][string]$MemberId,
        [Parameter(Mandatory)][string]$MemberName,
        [Parameter(Mandatory)][string]$Status
    )

    $riskNote = if ($Status -eq 'ExtraUnknownObject') { ' -- NOT a group this script recognizes; could be a user, device, or service principal' } else { '' }
    $target = "$MemberName -> $ParentName$riskNote"

    if ($PSCmdlet.ShouldProcess($target, 'REMOVE group membership')) {
        try {
            Remove-MgGroupMemberByRef -GroupId $ParentId -DirectoryObjectId $MemberId -Confirm:$false -ErrorAction Stop
            Write-Host "Removed: $target" -ForegroundColor Red
            return $true
        }
        catch {
            Write-Warning "Failed to remove $target : $($_.Exception.Message)"
            return $false
        }
    }
    return $false
}

# --- HTML report ---------------------------------------------------------------
# Shared by both modes' -ReportPath: if the path ends in .html/.htm, this is
# used instead of Export-Csv. Self-contained (inline CSS, no external files
# or network calls) so it works offline and can be emailed/attached as-is.
# Groups with any non-OK finding are expanded by default; fully healthy
# parent groups are collapsed, so the reader's eye goes straight to problems.
function Export-HtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Findings,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$Title,
        [string]$TenantId
    )

    function ConvertTo-HtmlText {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        return [System.Net.WebUtility]::HtmlEncode($Text)
    }

    $statusMeta = @{
        OK                  = @{ Label = 'OK';                    Class = 'ok';      Badge = 'ok' }
        Missing             = @{ Label = 'Missing';               Class = 'missing'; Badge = 'missing' }
        Extra               = @{ Label = 'Unexpected (recognized)';    Class = 'extra';   Badge = 'extra' }
        ExtraUnknownObject  = @{ Label = 'Unexpected (unrecognized)';  Class = 'extra';   Badge = 'unknown' }
        ParentGroupNotFound = @{ Label = 'Parent group not found'; Class = 'notfound'; Badge = 'notfound' }
        MemberGroupNotFound = @{ Label = 'Member group not found'; Class = 'notfound'; Badge = 'notfound' }
    }

    $summary = $Findings | Group-Object Status | Sort-Object Name
    $badgesHtml = ($summary | ForEach-Object {
        $meta = $statusMeta[$_.Name]
        $badgeClass = if ($meta) { $meta.Badge } else { 'default' }
        $label = if ($meta) { $meta.Label } else { $_.Name }
        "<div class='badge $badgeClass'><span class='count'>$($_.Count)</span>$(ConvertTo-HtmlText $label)</div>"
    }) -join "`n"

    $groups = $Findings | Group-Object ParentGroup | Sort-Object Name

    $groupsHtml = ($groups | ForEach-Object {
        $groupFindings = $_.Group | Sort-Object MemberGroup
        $hasIssue = @($groupFindings | Where-Object { $_.Status -ne 'OK' }).Count -gt 0
        $openAttr = if ($hasIssue) { ' open' } else { '' }
        $issueCount = @($groupFindings | Where-Object { $_.Status -ne 'OK' }).Count
        $statusSummary = if ($issueCount -gt 0) { "<span class='issue-count'>$issueCount issue$(if ($issueCount -ne 1) {'s'})</span>" } else { "<span class='clean'>clean</span>" }

        $rowsHtml = ($groupFindings | ForEach-Object {
            $meta = $statusMeta[$_.Status]
            $rowClass = if ($meta) { $meta.Class } else { 'default' }
            $pillClass = if ($meta) { $meta.Badge } else { 'default' }
            $label = if ($meta) { $meta.Label } else { $_.Status }
            "<tr class='row-$rowClass'><td>$(ConvertTo-HtmlText $_.MemberGroup)</td><td><span class='pill $pillClass'>$(ConvertTo-HtmlText $label)</span></td></tr>"
        }) -join "`n"

        @"
<details$openAttr>
  <summary><span class="parent-name">$(ConvertTo-HtmlText $_.Name)</span>$statusSummary</summary>
  <table>
    <thead><tr><th>Member group</th><th>Status</th></tr></thead>
    <tbody>
$rowsHtml
    </tbody>
  </table>
</details>
"@
    }) -join "`n"

    $generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $tenantLine = if ($TenantId) { "Tenant: $(ConvertTo-HtmlText $TenantId) &middot; " } else { '' }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$(ConvertTo-HtmlText $Title)</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
    margin: 0; padding: 32px; background: #f4f5f8; color: #1a1a2e;
    max-width: 1000px; margin-left: auto; margin-right: auto;
  }
  h1 { font-size: 22px; margin: 0 0 4px 0; }
  .meta { color: #666; font-size: 13px; margin-bottom: 24px; }
  .summary { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 28px; }
  .badge {
    padding: 10px 16px; border-radius: 10px; font-size: 12px; font-weight: 600;
    min-width: 100px; background: #eee; color: #555;
  }
  .badge .count { font-size: 24px; display: block; line-height: 1.3; }
  .badge.ok { background: #e6f4ea; color: #1e7e34; }
  .badge.missing { background: #fff8e1; color: #8a6500; }
  .badge.extra { background: #fdeeea; color: #b6431f; }
  .badge.unknown { background: #f3e8fd; color: #6c3483; }
  .badge.notfound { background: #fdeaea; color: #c0392b; }
  details {
    background: white; border-radius: 10px; margin-bottom: 10px;
    box-shadow: 0 1px 3px rgba(0,0,0,.08); overflow: hidden;
  }
  summary {
    padding: 12px 18px; cursor: pointer; list-style: none;
    display: flex; justify-content: space-between; align-items: center;
    font-weight: 600; font-size: 14px; background: #fafbfc;
  }
  summary::-webkit-details-marker { display: none; }
  summary:before { content: '▸ '; color: #999; }
  details[open] summary:before { content: '▾ '; }
  .parent-name { font-family: ui-monospace, "Cascadia Code", Consolas, monospace; font-size: 13px; }
  .issue-count { color: #b6431f; font-size: 12px; font-weight: 600; }
  .clean { color: #1e7e34; font-size: 12px; font-weight: 500; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 8px 18px; text-align: left; font-size: 13px; }
  th { color: #888; font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1px solid #eee; }
  tr.row-ok { color: #444; }
  tr.row-missing { background: #fffdf5; }
  tr.row-extra { background: #fef7f5; }
  tr.row-notfound { background: #fdf3f2; }
  td { font-family: ui-monospace, "Cascadia Code", Consolas, monospace; }
  .pill {
    display: inline-block; padding: 3px 10px; border-radius: 12px;
    font-size: 11px; font-weight: 600; font-family: -apple-system, "Segoe UI", Roboto, sans-serif;
  }
  .pill.ok { background: #e6f4ea; color: #1e7e34; }
  .pill.missing { background: #fff8e1; color: #8a6500; }
  .pill.extra { background: #fdeeea; color: #b6431f; }
  .pill.unknown { background: #f3e8fd; color: #6c3483; }
  .pill.notfound { background: #fdeaea; color: #c0392b; }
</style>
</head>
<body>
  <h1>$(ConvertTo-HtmlText $Title)</h1>
  <div class="meta">${tenantLine}Generated $generatedAt</div>
  <div class="summary">
$badgesHtml
  </div>
  <div class="groups">
$groupsHtml
  </div>
</body>
</html>
"@

    Set-Content -Path $OutputPath -Value $html -Encoding UTF8
}

if ($Check) {
    # ==========================================================================
    # CHECK MODE — read-only audit, no writes
    # ==========================================================================
    $findings = [System.Collections.Generic.List[object]]::new()

    # Pass 1: every CSV row -> OK / Missing / group-not-found
    foreach ($row in $rows) {
        $parentName = $row.ParentGroup.Trim()
        $memberName = $row.MemberGroup.Trim()
        $parentId = $groupMap[$parentName]
        $memberId = $groupMap[$memberName]

        if (-not $parentId) {
            $findings.Add([pscustomobject]@{ ParentGroup = $parentName; MemberGroup = $memberName; Status = 'ParentGroupNotFound' })
            continue
        }
        if (-not $memberId) {
            $findings.Add([pscustomobject]@{ ParentGroup = $parentName; MemberGroup = $memberName; Status = 'MemberGroupNotFound' })
            continue
        }

        $existing = Get-ExistingMemberIds -ParentId $parentId
        if ($existing.Contains($memberId)) {
            $findings.Add([pscustomobject]@{ ParentGroup = $parentName; MemberGroup = $memberName; Status = 'OK' })
        }
        else {
            $findings.Add([pscustomobject]@{ ParentGroup = $parentName; MemberGroup = $memberName; Status = 'Missing' })
        }
    }

    # Pass 2: unexpected/unrecognized members -- shared with Apply mode, see Get-DriftFindings above
    $driftFindings = Get-DriftFindings -ExpectedByParent $expectedByParent -GroupMap $groupMap -IdToName $idToName
    foreach ($d in $driftFindings) { $findings.Add($d) }

    # --- Report -----------------------------------------------------------------
    Write-Host "`n--- Check results ---" -ForegroundColor Cyan
    foreach ($f in ($findings | Sort-Object ParentGroup, MemberGroup)) {
        $color = switch ($f.Status) {
            'OK'                  { 'DarkGray' }
            'Missing'             { 'Yellow' }
            'Extra'               { 'Magenta' }
            'ExtraUnknownObject'  { 'Magenta' }
            'ParentGroupNotFound' { 'Red' }
            'MemberGroupNotFound' { 'Red' }
            default               { 'White' }
        }
        Write-Host ("{0,-22} {1,-55} {2}" -f $f.Status, $f.MemberGroup, "-> $($f.ParentGroup)") -ForegroundColor $color
    }

    $summary = $findings | Group-Object Status | Sort-Object Name
    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    foreach ($s in $summary) { Write-Host ("{0,-22}: {1}" -f $s.Name, $s.Count) }

    if ($ReportPath) {
        if ($ReportPath -match '\.html?$') {
            Export-HtmlReport -Findings $findings -OutputPath $ReportPath -Title "Nested Group Membership — Check Report (phase: $Phase)" -TenantId (Get-MgContext).TenantId
        }
        else {
            $findings | Sort-Object ParentGroup, MemberGroup | Export-Csv -Path $ReportPath -NoTypeInformation
        }
        Write-Host "`nFull report written to $ReportPath" -ForegroundColor Cyan
    }

    $driftCount = ($findings | Where-Object { $_.Status -ne 'OK' }).Count
    if ($driftCount -gt 0) {
        Write-Warning "$driftCount relationship(s) don't match the CSV. Run without -Check to apply missing memberships (Extra/unexpected memberships are reported only — this script never removes anything)."
        exit 1
    }
    else {
        Write-Host "`nAll nested memberships match the CSV. No drift found." -ForegroundColor Green
        exit 0
    }
}

# ==========================================================================
# APPLY MODE — adds missing memberships (original behaviour)
# ==========================================================================
$stats = [ordered]@{
    GroupsCreated     = $groupsCreated
    Added             = 0
    AlreadyMember     = 0
    MissingParent     = 0
    MissingMember     = 0
    Errors            = 0
    UnexpectedMembers = 0
    Removed           = 0
}

foreach ($row in $rows) {
    $parentName = $row.ParentGroup.Trim()
    $memberName = $row.MemberGroup.Trim()

    $parentId = $groupMap[$parentName]
    $memberId = $groupMap[$memberName]

    if (-not $parentId) {
        Write-Warning "Parent group not found in Entra ID: $parentName"
        $stats.MissingParent++
        continue
    }
    if (-not $memberId) {
        Write-Warning "Member group not found in Entra ID: $memberName (parent: $parentName)"
        $stats.MissingMember++
        continue
    }

    $existing = Get-ExistingMemberIds -ParentId $parentId
    if ($existing.Contains($memberId)) {
        Write-Verbose "Already nested: $memberName -> $parentName"
        $stats.AlreadyMember++
        continue
    }

    $target = "$memberName -> $parentName"
    if ($PSCmdlet.ShouldProcess($target, 'Add nested group membership')) {
        try {
            $params = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$memberId" }
            New-MgGroupMemberByRef -GroupId $parentId -BodyParameter $params
            Write-Host "Added: $target" -ForegroundColor Green
            $existing.Add($memberId) | Out-Null
            $stats.Added++
        }
        catch {
            Write-Warning "Failed to add $target : $($_.Exception.Message)"
            $stats.Errors++
        }
    }
}

# Flag unexpected/unrecognized members here too, not just under -Check --
# whether a member IS one of our own baseline groups (just under the wrong
# parent) or something we don't recognize at all, it gets reported and
# left exactly as it is. This never removes anything; see Get-DriftFindings.
$driftFindings = Get-DriftFindings -ExpectedByParent $expectedByParent -GroupMap $groupMap -IdToName $idToName
if ($driftFindings.Count -gt 0) {
    Write-Host "`n--- Unexpected members found ---" -ForegroundColor Yellow
    foreach ($d in ($driftFindings | Sort-Object ParentGroup, MemberGroup)) {
        $label = if ($d.Status -eq 'ExtraUnknownObject') { 'not a group we recognize' } else { 'a recognized group, but not expected under this parent' }
        Write-Warning "$($d.MemberGroup) is nested under $($d.ParentGroup) ($label)"
    }
    $stats.UnexpectedMembers = $driftFindings.Count

    if ($ReportPath) {
        if ($ReportPath -match '\.html?$') {
            Export-HtmlReport -Findings $driftFindings -OutputPath $ReportPath -Title "Nested Group Membership — Unexpected Members (phase: $Phase)" -TenantId (Get-MgContext).TenantId
        }
        else {
            $driftFindings | Sort-Object ParentGroup, MemberGroup | Export-Csv -Path $ReportPath -NoTypeInformation
        }
        Write-Host "Unexpected-member report written to $ReportPath" -ForegroundColor Cyan
    }

    # Removal is entirely separate from flagging above, and entirely opt-in.
    if ($RemoveUnexpectedMembers) {
        $toRemove = $driftFindings | Where-Object { $_.Status -eq 'Extra' -or ($IncludeUnrecognizedObjects -and $_.Status -eq 'ExtraUnknownObject') }
        if ($toRemove) {
            Write-Host "`n--- Removing unexpected members (each requires its own confirmation) ---" -ForegroundColor Red
            foreach ($d in ($toRemove | Sort-Object ParentGroup, MemberGroup)) {
                $removed = Remove-UnexpectedGroupMember -ParentId $d.ParentId -ParentName $d.ParentGroup -MemberId $d.MemberId -MemberName $d.MemberGroup -Status $d.Status
                if ($removed) { $stats.Removed++ }
            }
        }
        $skippedUnrecognized = @($driftFindings | Where-Object { $_.Status -eq 'ExtraUnknownObject' }).Count
        if ($skippedUnrecognized -gt 0 -and -not $IncludeUnrecognizedObjects) {
            Write-Warning "$skippedUnrecognized unrecognized-object finding(s) were left alone. Add -IncludeUnrecognizedObjects to also remove those."
        }
    }
    elseif ($IncludeUnrecognizedObjects) {
        Write-Warning "-IncludeUnrecognizedObjects has no effect without -RemoveUnexpectedMembers."
    }
}
elseif ($RemoveUnexpectedMembers -or $IncludeUnrecognizedObjects) {
    Write-Host "No unexpected members found -- nothing to remove." -ForegroundColor Cyan
}

# --- Summary -----------------------------------------------------------------
Write-Host "`n--- Summary ---" -ForegroundColor Cyan
$stats.GetEnumerator() | ForEach-Object { Write-Host ("{0,-14}: {1}" -f $_.Key, $_.Value) }

if ($stats.MissingParent -gt 0 -or $stats.MissingMember -gt 0) {
    $suggestion = if ($CreateMissingGroups) { 'Check the "Failed to create group" warnings above.' } else { 'Re-run with -CreateMissingGroups to create them automatically, or run your group-creation automation first.' }
    Write-Warning "Some groups referenced in the CSV do not exist yet in Entra ID (or fell outside -GroupPrefix). $suggestion"
}

if ($stats.UnexpectedMembers -gt 0) {
    Write-Warning "$($stats.UnexpectedMembers) unexpected member(s) found and flagged above -- none were touched. Review them and remove manually if they're not supposed to be there."
}

}
catch {
    Write-Host ""
    Write-Host "=== Script failed ===" -ForegroundColor Red
    Write-Host "Error:  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "At:     line $($_.InvocationInfo.ScriptLineNumber) of $($_.InvocationInfo.ScriptName)" -ForegroundColor Red
    Write-Host "Line:   $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "Stack:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    exit 1
}
