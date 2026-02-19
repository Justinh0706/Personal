# ==============================
# CONFIGURATIE
# ==============================

$TaskName      = "StartScript-Import-Export"
$UncScriptPath = ""
$TaskFolder    = "\Supracom"
$Description     = "Start een script op de srv-01 die ervoor zorgt dat de import-export map verwijderd wordt en daarna opnieuw aangemaakt wordt. Dit zorgt ervoor dat de verkenner niet vastloopt bij de import-export map"

# Huidige gebruiker ophalen
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# ==============================
# VALIDATIE
# ==============================

if (-not ($UncScriptPath -match '^[\\]{2}')) {
    throw "UncScriptPath moet een UNC pad zijn, bv \\server\share\script.ps1"
}

if (-not $TaskFolder.StartsWith("\")) { $TaskFolder = "\" + $TaskFolder }
if ($TaskFolder.EndsWith("\")) { $TaskFolder = $TaskFolder.TrimEnd("\") }

# ==============================
# TASK DEFINITIE
# ==============================

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$UncScriptPath`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew

# LogonType Interactive = alleen draaien als gebruiker is ingelogd
$Principal = New-ScheduledTaskPrincipal `
    -UserId $CurrentUser `
    -LogonType Interactive `

$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description $Description

# ==============================
# FOLDER AANMAKEN (indien nodig)
# ==============================

$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
$root = $service.GetFolder("\")

try {
    $null = $service.GetFolder($TaskFolder)
}
catch {
    $root.CreateFolder($TaskFolder) | Out-Null
}

# ==============================
# TASK REGISTREREN
# ==============================

$FullTaskName = "$TaskFolder\$TaskName"

Register-ScheduledTask `
    -TaskName $FullTaskName `
    -InputObject $Task `
    -Force

Write-Host "Task aangemaakt voor gebruiker: $CurrentUser" -ForegroundColor Green
Write-Host "Locatie: $FullTaskName"
