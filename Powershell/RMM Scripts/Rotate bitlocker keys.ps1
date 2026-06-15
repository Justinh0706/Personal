# Run elevated (Administrator)
$logFile = "C:\BitLockerRecoveryKeyHistory.txt"

# Admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Run this script as Administrator."
    exit 1
}

# BitLocker cmdlets beschikbaar?
if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
    Write-Host "Skipped: BitLocker cmdlets are not available on this system."
    exit 0
}

$volumes = Get-BitLockerVolume

foreach ($volume in $volumes) {
    $mp = $volume.MountPoint
    if ($volume.ProtectionStatus -ne 'On') {
        Write-Host "BitLocker is not enabled on volume: $mp"
        continue
    }

    Write-Host "Inspecting volume: $mp"
    $protectors = $volume.KeyProtector
    if (-not $protectors) {
        Write-Host "No key protectors returned for $mp"
    } else {
        Write-Host "Found key protector types for ${mp}:"
        $protectors | ForEach-Object { Write-Host " - Type: $($_.KeyProtectorType)  Id: $($_.KeyProtectorId)" }
    }

    # Try to find an existing RecoveryPassword with an actual password value
    $rp = $protectors | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' -and $_.PSObject.Properties.Match('RecoveryPassword') -and $_.RecoveryPassword }
    if ($rp) {
        $recoveryKey = $rp.RecoveryPassword
        Write-Host "Recovery password found for $mp : (hidden)"
        # Log if not already present
        $entry = "Volume: $mp - Recovery Key: $recoveryKey"
        if (-not (Test-Path $logFile) -or -not (Get-Content $logFile | Where-Object { $_ -eq $entry })) {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Add-Content -Path $logFile -Value "$timestamp - $entry"
            Write-Host "OK: Recovery key for $mp added to history."
        } else {
            Write-Host "No change: recovery key already in history."
        }
        continue
    }

    Write-Host "No RecoveryPassword protector with value found for $mp."

    # Option: add a new RecoveryPassword protector and record it
    try {
        Write-Host "Adding a new RecoveryPassword protector to $mp..."
        $added = Add-BitLockerKeyProtector -MountPoint $mp -RecoveryPasswordProtector -ErrorAction Stop
        $addedId = $added.KeyProtectorId
        Start-Sleep -Seconds 1
        $volume2 = Get-BitLockerVolume -MountPoint $mp
        $rpNew = $volume2.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' -and $_.KeyProtectorId -eq $addedId }
        if ($rpNew -and $rpNew.RecoveryPassword) {
            $newKey = $rpNew.RecoveryPassword
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $entry = "Volume: $mp - Recovery Key: $newKey"
            Add-Content -Path $logFile -Value "$timestamp - $entry"
            Write-Host "OK: New recovery key added for $mp and logged."
        } else {
            Write-Host "Added protector but could not read the RecoveryPassword property. Check environment/permissions or inspect protectors manually."
            $volume2.KeyProtector | ForEach-Object { Write-Host " - Type: $($_.KeyProtectorType)  Id: $($_.KeyProtectorId)" }
        }
    }
    catch {
        Write-Host "Failed to add recovery protector for ${mp}: $_"
    }
}

# Show log tail
if (Test-Path $logFile) {
    Write-Host "`n--- BitLocker Recovery Key History (last 50 lines) ---"
    Get-Content $logFile -Tail 50 | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No recovery key history file exists."
}

exit 0