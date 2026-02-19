# Uninstall script to remove Chrome/Edge extension policies

# Chrome keys
$chromeExtensionId = "benimdeioplgkhanklclahllklceahbe"
$chromeManagedStorageKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\$chromeExtensionId"
$chromeExtensionSettingsKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionSettings\$chromeExtensionId"

# Edge keys
$edgeExtensionId = "knepjpocdagponkonnbggpcnhnaikajg"
$edgeManagedStorageKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\$edgeExtensionId"
$edgeExtensionSettingsKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings\$edgeExtensionId"

# Function to remove extension policies
function Remove-ExtensionSettings {
    param (
        [string]$ManagedStorageKey,
        [string]$ExtensionSettingsKey,
        [string]$ExtensionId
    )

    if (Test-Path $ManagedStorageKey) {
        Remove-Item -Path $ManagedStorageKey -Recurse -Force
        Write-Output "Removed managed storage for $ExtensionId"
    }

    if (Test-Path $ExtensionSettingsKey) {
        Remove-Item -Path $ExtensionSettingsKey -Recurse -Force
        Write-Output "Removed extension settings for $ExtensionId"
    }
}

# Remove Chrome and Edge policies
Remove-ExtensionSettings -ManagedStorageKey $chromeManagedStorageKey -ExtensionSettingsKey $chromeExtensionSettingsKey -ExtensionId $chromeExtensionId
Remove-ExtensionSettings -ManagedStorageKey $edgeManagedStorageKey -ExtensionSettingsKey $edgeExtensionSettingsKey -ExtensionId $edgeExtensionId

Write-Output "Extension policies removed. Restart Chrome/Edge for changes to apply."
