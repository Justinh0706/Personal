<#
    .SYNOPSIS
        Windows 11 Feature Update installer.
    .DESCRIPTION
        This script downloads and silently executes the Windows 11 Installation Assistant to install the latest Windows 11 Feature Update.
        You can use your RMM or other environment to populate the variables 'featureUpgradeDir' and/or 'featureUpgradeFile' or use the defaults.
#>
Begin {
    # Only run this script on allowed computer names. List provided by RMM/operations.
      $AllowedComputerNames = @(
        'SID-103798','SID-105964','SID-103643','SID-104111'
    ) | ForEach-Object { $_.Trim().ToUpper() }

    $CurrentComputer = $env:COMPUTERNAME
    if ($null -eq $CurrentComputer) {
        Write-Host "Unable to determine computer name. Exiting."
        Exit 1
    }
    if (-not ($AllowedComputerNames -contains $CurrentComputer.ToUpper())) {
        Write-Host "Computer '$CurrentComputer' is not in the allowed list. Exiting."
        Exit 0
    }

    if (![String]::IsNullOrWhiteSpace($ENV:FeatureUpgradeDir)) {
        $FeatureUpgradeDir = $ENV:FeatureUpgradeDir
    } else {
        $FeatureUpgradeDir = 'C:\RMM\FeatureUpdates'
    }
    if (![String]::IsNullOrWhiteSpace($ENV:FeatureUpgradeFile)) {
        $FeatureUpgradeFile = $ENV:FeatureUpgradeFile
    } else {
        # Ensure we always have a valid path for FeatureUpgradeFile so Test-Path is not called with $null
        $FeatureUpgradeFile = Join-Path -Path $FeatureUpgradeDir -ChildPath 'Windows11InstallationAssistant.exe'
    }
    if (!(Test-Path $FeatureUpgradeDir)) {
        New-Item $FeatureUpgradeDir -Force -ErrorAction SilentlyContinue -ItemType Directory | Out-Null
    }
    $LoggingDir = Join-Path -Path $FeatureUpgradeDir -ChildPath 'Logs'
    if (!(Test-Path $LoggingDir)) {
        New-Item $LoggingDir -Force -ErrorAction SilentlyContinue -ItemType Directory | Out-Null
    }
    $DownloadURI = 'https://go.microsoft.com/fwlink/?linkid=2171764'  
    Try {
        $WebClient = [System.Net.WebClient]::new()
        $WebClient.DownloadFile($DownloadURI, $FeatureUpgradeFile)
    } Catch {
        Write-Error "Could not download the Update Assistant."
        Exit 1
    }
}
Process {
    Try {
        
        Start-Process -FilePath $featureUpgradeFile -ArgumentList @('/quietinstall', '/skipeula', '/auto', 'upgrade', '/copylogs', $LoggingDir) -Wait -NoNewWindow
    } Catch {
        Write-Host "The Windows 11 Installation Assistant failed."
        Exit 1
    }
}
