<#
.SYNOPSIS
  Wrapper voor het draaien van Secure-Boot-Certificate.ps1 vanuit een 32-bit PowerShell sessie.
.DESCRIPTION
  Als dit script in een 32-bit PowerShell sessie wordt gestart op een 64-bit Windows-systeem,
  wordt automatisch de 64-bit PowerShell gebruikt om het echte Secure Boot deployment script te starten.
.PARAMETER AutoReboot
  Schakelt autonoom herstarten in wanneer het Secure Boot update proces dat vereist.
.PARAMETER PollSeconds
  Hoelang er gepolld wordt op voortgang.
.PARAMETER LogPath
  Pad voor het logbestand van het Secure Boot deployment script.
#>

[CmdletBinding()]
param(
    [switch]$AutoReboot,
    [int]$PollSeconds = 90,
    [string]$LogPath = "C:\ProgramData\SecureBoot\SecureBoot-Cert-Deploy.log"
)

function Get-64BitPowerShell {
    # In een 32-bit PS op een 64-bit machine is Sysnative beschikbaar.
    $sysnative = Join-Path $env:windir 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $sysnative) {
        return $sysnative
    }

    # Fallback voor 64-bit PowerShell op systemen zonder Sysnative (bijvoorbeeld al in 64-bit sessie).
    return Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

function Is-CurrentSession32Bit {
    return $PSHOME -match '\\SysWOW64$'
}

$targetScript = 'C:\temp\Secure-Boot-Certificate.ps1'

if (-not (Test-Path $targetScript)) {
    Write-Error "Doelscript niet gevonden: $targetScript"
    exit 1
}

$scriptParams = @()
if ($AutoReboot) { $scriptParams += '-AutoReboot' }
if ($PSBoundParameters.ContainsKey('PollSeconds')) {
    $scriptParams += '-PollSeconds'; $scriptParams += $PollSeconds
}
if ($PSBoundParameters.ContainsKey('LogPath')) {
    $scriptParams += '-LogPath'; $scriptParams += $LogPath
}

if (Is-CurrentSession32Bit) {
    $powershellExe = Get-64BitPowerShell
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $targetScript) + $scriptParams
    Write-Host "32-bit PowerShell gedetecteerd; start 64-bit PowerShell: $powershellExe"
    $process = Start-Process -FilePath $powershellExe -ArgumentList $argumentList -Wait -PassThru
    exit $process.ExitCode
}

Write-Host "64-bit PowerShell sessie of geen SysWOW64-detectie, voer Secure-Boot-Certificate.ps1 direct uit."
& $targetScript @scriptParams

# Direct uitvoeren met alle parameters zoals hierboven samengesteld.
