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

    # Try to find an existing RecoveryPassword protector
    $rp = $protectors | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    
    # ROTATE: Remove old recovery key if it exists
    if ($rp) {
        Write-Host "Removing old RecoveryPassword protector from $mp..."
        try {
            Remove-BitLockerKeyProtector -MountPoint $mp -KeyProtectorId $rp.KeyProtectorId -ErrorAction Stop
            Write-Host "OK: Old recovery protector removed."
            Start-Sleep -Seconds 1
        }
        catch {
            Write-Host "Failed to remove old protector: $_"
        }
    }

    # Add new RecoveryPassword protector
    try {
        Write-Host "Adding new RecoveryPassword protector to $mp..."
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
            Write-Host "OK: New recovery key created and logged for $mp"
        } else {
            Write-Host "Added protector but could not read the RecoveryPassword property."
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