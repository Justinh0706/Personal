$Registrypath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD"
$registryKey = "AutoAcceptSsoPermission"
$registryValue = 1  
$registryType = "DWORD"

New-item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD" -Force | Out-Null
new-itemproperty -Path $Registrypath -Name $registryKey -Value $registryValue -PropertyType $registryType -Force | Out-Null