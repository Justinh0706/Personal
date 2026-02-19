<#
.SYNOPSIS
    Dit script maakt een Windows Autopilot deployment profile aan in Microsoft Intune
    en wijst deze toe aan een specifieke Microsoft Entra ID-groep.

.DESCRIPTION
    Het script voert de volgende acties uit:
    1. Importeert expliciet de vereiste Microsoft Graph-modules voor stabiliteit.
    2. Maakt verbinding met de Microsoft Graph API met de benodigde permissies.
    3. Definieert en maakt een nieuw Autopilot-profiel aan.
    4. Zoekt de opgegeven groep op en wijst het profiel toe.
    
    VOORWAARDE: De Microsoft.Graph module moet vooraf geïnstalleerd zijn.
    Gebruik: Install-Module Microsoft.Graph -Scope AllUsers

.AUTHOR
    AI Assistant (V4 - Robuust met expliciete imports)
#>

# --- Instellingen ---
$profileName = "Autopilot profile"
$assignmentGroupName = "Autopilot test"

# --- Stap 1: Benodigde modules expliciet importeren ---
Write-Host "Stap 1: Vereiste modules importeren..." -ForegroundColor Yellow

<#Uninstall-Module Microsoft.Graph -AllVersions -Force

Install-module Microsoft.Graph -Allversions -Force
#>
<#try {
    # We importeren de modules expliciet om "cmdlet not found" fouten te voorkomen.
    Import-Module Microsoft.Graph.Authentication
    Import-Module Microsoft.Graph.DeviceManagement.Enrolment
    Import-Module Microsoft.Graph.Groups
    Write-Host "Modules succesvol geïmporteerd." -ForegroundColor Green
}
catch {
    Write-Error "Fout bij het importeren van een vereiste module. Controleer of de Microsoft.Graph SDK correct is geïnstalleerd (Install-Module Microsoft.Graph -Scope AllUsers). De fout was: $_"
    return # Stop het script
}
#>
# --- Stap 2: Maak verbinding met Microsoft Graph ---
Write-Host "`nStap 2: Verbinden met Microsoft Graph..." -ForegroundColor Yellow
Write-Host "Er wordt een pop-up venster geopend om in te loggen. Gebruik een account met Intune Administrator of Global Administrator rechten." -ForegroundColor Cyan

try {
    $scopes = @("DeviceManagementServiceConfig.ReadWrite.All", "Group.Read.All")
    Connect-MgGraph -Scopes $scopes
    Write-Host "Succesvol verbonden met Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Error "Kon geen verbinding maken met Microsoft Graph. Controleer je internetverbinding en permissies."
    return
}

# --- Stap 3: Definieer en maak het Autopilot Deployment Profile aan ---
Write-Host "`nStap 3: Het Autopilot-profiel '$profileName' aanmaken..." -ForegroundColor Yellow

$profileParams = @{
    DisplayName = $profileName
    Description = "Profiel aangemaakt via PowerShell script"
    DeviceType = "windowsPc"
    DeploymentMode = "userDriven"
    JoinToMicrosoftEntraIdAs = "azureADJoined"
    ExtractHardwareHash = $true
    HideEula = $false
    HidePrivacySettings = $false
    HideChangeAccountOptions = $false
    EnableWhiteGlove = $false
    Language = "os-default"
}

try {
    $newProfile = New-MgDeviceManagementWindowsAutopilotDeploymentProfile -BodyParameter $profileParams
    Write-Host "Profiel '$($newProfile.DisplayName)' succesvol aangemaakt met ID: $($newProfile.Id)" -ForegroundColor Green
}
catch {
    Write-Error "Fout bij het aanmaken van het Autopilot-profiel. $_"
    return
}

# --- Stap 4: Wijs het profiel toe aan de groep ---
Write-Host "`nStap 4: Profiel toewijzen aan de groep '$assignmentGroupName'..." -ForegroundColor Yellow

try {
    $targetGroup = Get-MgGroup -Filter "displayName eq '$assignmentGroupName'"
    
    if (-not $targetGroup) {
        Write-Error "De groep '$assignmentGroupName' kon niet worden gevonden in Microsoft Entra ID."
        return
    }

    $assignment = @{
        target = @{
            "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
            groupId = $targetGroup.Id
        }
    }

    New-MgDeviceManagementWindowsAutopilotDeploymentProfileAssignment -WindowsAutopilotDeploymentProfileId $newProfile.Id -BodyParameter $assignment
    Write-Host "Profiel succesvol toegewezen aan de groep '$assignmentGroupName'." -ForegroundColor Green
}
catch {
    Write-Error "Fout bij het toewijzen van het profiel aan de groep. $_"
    return
}

Write-Host "`nScript succesvol voltooid." -ForegroundColor Green
# Disconnect-MgGraph # Uncomment deze regel als je de verbinding automatisch wilt verbreken aan het einde.