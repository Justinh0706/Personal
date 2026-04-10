# SecureBoot-Cert-Deploy.ps1
# Doel:
# - forceert de Windows Secure Boot certificate deployment op een device
# - geschikt voor uitrol via Intune / SCCM / startup script / RMM
# - gebruikt de Microsoft-servicing flow, niet handmatig UEFI-certificaten injecteren

[CmdletBinding()]
param(
    [switch]$AutoReboot,
    [int]$PollSeconds = 90,
    [string]$LogPath = "C:\ProgramData\SecureBoot\SecureBoot-Cert-Deploy.log"
)

$ErrorActionPreference = "Stop"

# ----------------------------
# Logging
# ----------------------------
$logDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogPath -Value $line
    Write-Output $line
}

# ----------------------------
# Admin check
# ----------------------------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Script moet elevated draaien." "ERROR"
    exit 1001
}

# ----------------------------
# Helpers
# ----------------------------
$sbRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot"
$sbSvc  = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
$taskPath = "\Microsoft\Windows\PI\Secure-Boot-Update"

function Get-RegValueSafe {
    param(
        [string]$Path,
        [string]$Name
    )
    try {
        return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
    }
    catch {
        return $null
    }
}

function Get-SecureBootState {
    $availableUpdates = Get-RegValueSafe -Path $sbRoot -Name "AvailableUpdates"
    $status           = Get-RegValueSafe -Path $sbSvc  -Name "UEFICA2023Status"
    $errorCode        = Get-RegValueSafe -Path $sbSvc  -Name "UEFICA2023Error"
    $errorEvent       = Get-RegValueSafe -Path $sbSvc  -Name "UEFICA2023ErrorEvent"

    [pscustomobject]@{
        AvailableUpdates = $availableUpdates
        Status           = $status
        ErrorCode        = $errorCode
        ErrorEvent       = $errorEvent
    }
}

function Confirm-TaskExists {
    try {
        $null = Get-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update" -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Ensure-TaskEnabled {
    $task = Get-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update"
    if ($task.State -eq "Disabled") {
        Enable-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update" | Out-Null
        Write-Log "Scheduled task Secure-Boot-Update was disabled; enabled now."
    }
}

function Start-SecureBootTask {
    Start-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update"
    Write-Log "Scheduled task gestart: $taskPath"
}

function Test-PendingReboot {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $true }
    }
    return $false
}

# ----------------------------
# Platform check
# ----------------------------
try {
    $secureBootEnabled = Confirm-SecureBootUEFI
}
catch {
    Write-Log "Dit apparaat ondersteunt Confirm-SecureBootUEFI niet of draait niet in UEFI-modus." "ERROR"
    exit 1002
}

if (-not $secureBootEnabled) {
    Write-Log "Secure Boot staat niet aan op dit apparaat." "ERROR"
    exit 1003
}

if (-not (Confirm-TaskExists)) {
    Write-Log "Scheduled task $taskPath ontbreekt. Zonder deze task werkt servicing niet." "ERROR"
    exit 1004
}

Ensure-TaskEnabled

# ----------------------------
# Huidige status
# ----------------------------
$current = Get-SecureBootState
Write-Log ("Startstatus - AvailableUpdates={0} Status={1} Error={2} ErrorEvent={3}" -f `
    $current.AvailableUpdates, $current.Status, $current.ErrorCode, $current.ErrorEvent)

if ($current.Status -eq "Updated") {
    Write-Log "Device is al bijgewerkt. Geen actie nodig."
    exit 0
}

# ----------------------------
# Trigger deployment
# ----------------------------
New-Item -Path $sbRoot -Force | Out-Null
Set-ItemProperty -Path $sbRoot -Name "AvailableUpdates" -Type DWord -Value 0x5944
Write-Log "AvailableUpdates ingesteld op 0x5944."

Start-SecureBootTask

# ----------------------------
# Poll korte tijd op voortgang
# ----------------------------
$deadline = (Get-Date).AddSeconds($PollSeconds)

do {
    Start-Sleep -Seconds 5
    $state = Get-SecureBootState
    Write-Log ("Poll - AvailableUpdates={0} Status={1} Error={2} ErrorEvent={3}" -f `
        $state.AvailableUpdates, $state.Status, $state.ErrorCode, $state.ErrorEvent)

    if ($state.Status -eq "Updated") {
        Write-Log "Secure Boot certificaat-update is succesvol afgerond."
        exit 0
    }

    if ($null -ne $state.ErrorCode -and [int]$state.ErrorCode -ne 0) {
        Write-Log "Windows meldt een fout tijdens servicing. Controleer event logs voor Secure Boot events." "ERROR"
        exit 2001
    }

} while ((Get-Date) -lt $deadline)

# ----------------------------
# Evaluatie na polling
# ----------------------------
$final = Get-SecureBootState

if ($final.Status -eq "Updated") {
    Write-Log "Secure Boot certificaat-update is succesvol afgerond."
    exit 0
}

if ($final.AvailableUpdates -eq 0x4100) {
    Write-Log "Device zit in de reboot-fase (AvailableUpdates=0x4100). Na een reboot moet de Secure-Boot-Update task opnieuw kunnen lopen."

    if ($AutoReboot) {
        Write-Log "AutoReboot is ingeschakeld. Herstart wordt uitgevoerd over 60 seconden."
        shutdown.exe /r /t 60 /c "Secure Boot certificate deployment vervolgt na reboot."
        exit 3010
    }
    else {
        Write-Log "Nog geen reboot uitgevoerd. Plan een reboot in en laat de scheduled task opnieuw lopen."
        exit 3010
    }
}

if ($null -ne $final.ErrorCode -and [int]$final.ErrorCode -ne 0) {
    Write-Log ("Foutstatus gevonden. Error={0}, Event={1}" -f $final.ErrorCode, $final.ErrorEvent) "ERROR"
    exit 2002
}

if (Test-PendingReboot) {
    Write-Log "Er lijkt een pending reboot te zijn. Laat het apparaat herstarten en laat de task daarna opnieuw draaien."
    exit 3010
}

Write-Log "Deployment is gestart, maar nog niet afgerond binnen de polling-tijd. Laat de geplande taak later opnieuw draaien of monitor de status."
exit 0