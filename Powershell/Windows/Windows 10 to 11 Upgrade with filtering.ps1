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
        'SID-105964','SID-104111','SID-103798'
    ) | ForEach-Object { $_.Trim().ToUpper() } | Sort-Object -Unique

    $CurrentComputer = $env:COMPUTERNAME
    if ($null -eq $CurrentComputer) {
        Write-Host "Unable to determine computer name. Exiting."
        Exit 1
    }
    if (-not ($AllowedComputerNames -contains $CurrentComputer.ToUpper())) {
        Write-Host "Computer '$CurrentComputer' is not in the allowed list. Exiting."
        Exit 0
    }

    # If the machine is already running Windows 11 (build 22000 or newer), exit early.
    Try {
        $currBuild = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber -ErrorAction Stop).CurrentBuildNumber
    } Catch {
        # Could not read build number; continue with upgrade logic
        $currBuild = $null
    }
    if ($currBuild -and ([int]$currBuild -ge 22000)) {
        Write-Host "Computer '$CurrentComputer' is already running Windows 11 (build $currBuild). Exiting."
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
