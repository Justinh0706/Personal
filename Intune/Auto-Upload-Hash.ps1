<#
.SYNOPSIS
    Automatisch uploaden van hardware hash naar Microsoft Intune voor Windows Autopilot met certificate authenticatie.

.DESCRIPTION
    Dit script toont een keuze menu voor klanten, haalt de hardware hash op met dezelfde logica als Get-WindowsAutoPilotInfo,
    verbindt silent met Microsoft Graph via certificate authenticatie, en uploadt de hash naar Intune.

.NOTES
    Zorg ervoor dat de app registraties de permissie DeviceManagementServiceConfig.ReadWrite.All hebben
    en dat de certificates zijn geüpload naar de app registraties.
    Dit script gebruikt geen client secret en is volledig silent na keuze.
#>

# Klant configuraties - voeg hier je klanten toe
$customerConfigs = @{
    "1" = @{
        Name = "Supracom Lab"
        TenantId = "dea8da50-2b68-46ce-ba58-f6cf5bac31c7"
        ClientId = "1829737d-27c2-406c-be1a-29fa4344a4d5"
        CertificateThumbprint = "7ED670356DBF648529C8410BF425B3BAE1D86C13"  # Vervang met daadwerkelijke thumbprint
    }
    "2" = @{
        Name = "Klant 2"
        TenantId = "189234zd"
        ClientId = "1aefdaf849jkak2"
        CertificateThumbprint = "THUMBPRINT_VOOR_KLANT2"  # Vervang met daadwerkelijke thumbprint
    }
    # Voeg meer klantfen toe als:
    # "3" = @{
    #     Name = "Klant 3"
    #     TenantId = "..."
    #     ClientId = "..."
    #     CertificateThumbprint = "..."
    # }
}

# Toon keuze menu
Write-Host "Selecteer een klant:" -ForegroundColor Cyan
foreach ($key in $customerConfigs.Keys | Sort-Object) {
    $config = $customerConfigs[$key]
    Write-Host "$key. $($config.Name) (Client ID: $($config.ClientId), Tenant ID: $($config.TenantId))"
}
Write-Host ""

$choice = Read-Host "Voer het nummer van de klant in"

if (-not $customerConfigs.ContainsKey($choice)) {
    Write-Error "Ongeldige keuze. Script wordt afgesloten."
    exit 1
}

# Stel variabelen in gebaseerd op keuze
$selectedConfig = $customerConfigs[$choice]
$TenantId = $selectedConfig.TenantId
$ClientId = $selectedConfig.ClientId
$CertificateThumbprint = $selectedConfig.CertificateThumbprint

Write-Host "Gekozen klant: $($selectedConfig.Name)" -ForegroundColor Green
Write-Host "Tenant ID: $TenantId" -ForegroundColor Green
Write-Host "Client ID: $ClientId" -ForegroundColor Green
Write-Host ""

# Functie om hardware hash op te halen (gebaseerd op Get-WindowsAutoPilotInfo.ps1 logica)
function Get-HardwareHash {
    try {
        Write-Host "Ophalen hardware hash..." -ForegroundColor Yellow

        # Maak CIM sessie
        $session = New-CimSession

        # Haal device details op
        $devDetail = Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'"

        if (-not $devDetail) {
            throw "Kon device details niet ophalen. Zorg ervoor dat het apparaat Windows 10/11 heeft."
        }

        # De DeviceHardwareData bevat de base64 encoded hardware hash direct
        $hardwareHash = $devDetail.DeviceHardwareData[0]

        # Haal systeem informatie op voor serial number en product key
        $computerSystem = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem
        $bios = Get-CimInstance -CimSession $session -ClassName Win32_BIOS
        $operatingSystem = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem

        $serialNumber = $bios.SerialNumber
        $productKey = $operatingSystem.SerialNumber  # Windows Product ID
        $manufacturer = $computerSystem.Manufacturer
        $model = $computerSystem.Model

        # Cleanup
        Remove-CimSession $session

        return @{
            "Device Serial Number" = $serialNumber
            "Windows Product ID" = $productKey
            "Hardware Hash" = $hardwareHash
            "Manufacturer" = $manufacturer
            "Model" = $model
        }
    }
    catch {
        Write-Error "Kon hardware hash niet ophalen: $_"
        exit 1
    }
}

# Controleer of Microsoft.Graph module geïnstalleerd is
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.Graph -Force -Scope CurrentUser
}

# Importeer benodigde modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement

# Verbind met Microsoft Graph (silent met certificate)
try {
    Write-Host "Verbinden met Microsoft Graph via certificate..." -ForegroundColor Yellow
    $certificate = Get-Item "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction Stop
    Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $certificate -NoWelcome
    Write-Host "Verbonden met Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Error "Kon niet verbinden met Microsoft Graph: $_"
    exit 1
}

# Haal hardware informatie op
$deviceInfo = Get-HardwareHash
Write-Host "Hardware hash opgehaald voor apparaat: $($deviceInfo.'Device Serial Number')" -ForegroundColor Green

# Upload de hash naar Intune
try {
    Write-Host "Uploading hardware hash naar Intune..." -ForegroundColor Yellow

    $body = @{
        '@odata.type' = '#microsoft.graph.importedWindowsAutopilotDeviceIdentity'
        'hardwareIdentifier' = $deviceInfo.'Hardware Hash'
        'serialNumber' = $deviceInfo.'Device Serial Number'
        'productKey' = $deviceInfo.'Windows Product ID'
        'importId' = [guid]::NewGuid().ToString()
    }

    New-MgDeviceManagementImportedWindowsAutopilotDeviceIdentity -BodyParameter $body

    Write-Host "Hardware hash succesvol geüpload naar Intune!" -ForegroundColor Green
}
catch {
    Write-Error "Fout bij uploaden: $_"
    exit 1
}

# Verbreek verbinding
Disconnect-MgGraph

Write-Host "Script voltooid." -ForegroundColor Green
