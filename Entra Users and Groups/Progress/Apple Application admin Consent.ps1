<# 
Admin Consent helper for Apple Internet Accounts + verification via Microsoft Graph
- Laat je een browser .exe kiezen via GUI (OpenFileDialog)
- Opent https://aka.ms/ConsentAppleApp in die browser
- Controleert vóór/na op OAuth2PermissionGrants

Vereisten:
  Install-Module Microsoft.Graph -Scope AllUsers

Draai bij voorkeur in Windows PowerShell 5.1 (ISE werkt ook), als (Global) Admin.
#>

$ErrorActionPreference = "Stop"

# --- Config ---
$ConsentUrl = "https://aka.ms/ConsentAppleApp"

# Apple Internet Accounts (Microsoft-managed app)
$AppleAppId = "f8d98a96-0999-43f5-8af3-69971c7bb423"

function Select-BrowserExe {
    # OpenFileDialog vereist STA
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
        throw @"
OpenFileDialog vereist STA.
Start dit script opnieuw in een STA-host, bijvoorbeeld:
  - Windows PowerShell ISE
  - Of: powershell.exe -STA -File .\jouwscript.ps1
  - Of (interactief): powershell.exe -STA
"@
    }

    Add-Type -AssemblyName System.Windows.Forms | Out-Null

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Executables (*.exe)|*.exe"
    $dialog.Title  = "Kies browser executable (bijv. msedge.exe / chrome.exe / firefox.exe)"
    $dialog.Multiselect = $false

    if ($dialog.ShowDialog() -ne "OK" -or -not (Test-Path $dialog.FileName)) {
        throw "Geen (geldige) browser gekozen."
    }

    return $dialog.FileName
}

function Get-AppleOauth2Grants {
    param([string]$ServicePrincipalId)
    # Delegated permission grants (tenant-wide admin consent creëert doorgaans deze grants)
    Get-MgOauth2PermissionGrant -Filter "clientId eq '$ServicePrincipalId'" -All
}

Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "Application.Read.All","DelegatedPermissionGrant.Read.All" | Out-Null

Write-Host "Finding service principal for Apple Internet Accounts (appId=$AppleAppId)..."
$sp = Get-MgServicePrincipal -Filter "appId eq '$AppleAppId'" -ConsistencyLevel eventual -CountVariable c

if (-not $sp) {
    throw "Service principal niet gevonden. Mogelijk is de app nog nooit in je tenant gebruikt."
}

Write-Host "Found: $($sp.DisplayName)  (ObjectId=$($sp.Id))"

Write-Host "`nChecking existing OAuth2PermissionGrants..."
$before = Get-AppleOauth2Grants -ServicePrincipalId $sp.Id

if ($before.Count -gt 0) {
    Write-Host "✅ Consent/grants lijken al aanwezig (aantal grants: $($before.Count))."
    $before | Select-Object Id, ResourceId, Scope, ConsentType | Format-Table -AutoSize
} else {
    Write-Host "⚠️ Geen grants gevonden. Admin consent is waarschijnlijk nog niet tenant-wide gegeven."
}

Write-Host "`nKies nu de browser waarmee je de admin-consent wilt doen (handig voor andere tenants/omgevingen)."
$browserExe = Select-BrowserExe
Write-Host "Browser gekozen: $browserExe"

Write-Host "`nOpening admin-consent URL..."
Start-Process -FilePath $browserExe -ArgumentList @($ConsentUrl)

Write-Host @"
➡️ Rond nu in de browser de consent af met een (Global) Admin account van de JUISTE omgeving/tenant:
   - 'Accept' / 'Accepteren namens de organisatie'

Daarna druk je hier op ENTER om opnieuw te controleren.
"@
[void](Read-Host)

Write-Host "`nRe-checking OAuth2PermissionGrants..."
$after = Get-AppleOauth2Grants -ServicePrincipalId $sp.Id

if ($after.Count -gt 0) {
    Write-Host "✅ Klaar! Grants zijn nu aanwezig (aantal grants: $($after.Count))."
    $after | Select-Object Id, ResourceId, Scope, ConsentType | Format-Table -AutoSize
} else {
    Write-Host "❌ Nog steeds geen grants zichtbaar. Mogelijk is de consent niet afgerond of wordt het door policy geblokkeerd."
    Write-Host "Tip: check Entra ID -> Enterprise applications -> (Apple Internet Accounts) -> Permissions."
}
