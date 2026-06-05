# Quick acces Powershell 

## Enable Windows Firewall with CMD
### Turn on/off Firewall 
```
netsh advfirewall set allprofiles state on
```
### Show Firewall Status
```
netsh advfirewall show allprofiles
```

## Disabling Direct Send
### Connect to Exchange
```Powershell
Connect-exchangeonline
```
### Check Status
```Powershell
Get-OrganizationConfig | Select-Object Identity, RejectDirectSend
```
### Turn on/off Direct send
```Powershell
Set-OrganizationConfig -RejectDirectSend $true
```
## Edit calender permissions
### Get currect calender permisions (Connect to ExchangeOnline)
```powershell
Get-mailboxfolderpermission -identity "user@domain.nl:\agenda" | ft identity,foldername,user,accesrights
```
### Edit permisions (Permissions: editor, reviewer, noneediting author, Availabilityonly)
```powershell
Add-Mailboxfolderpermission -identity "user@domain.nl:\agenda -User "accesuser@domain.nl" -Accesrights reviewer
```
## Delete Sharepoint Sites
### Connect to tenant
```
Connect-SPOService -Url https://contoso-admin.sharepoint.com
```
### Get Sites
```powershell
Get-sposite
```
```powershell
get-spodeletedsite
```
### Remove Sites
```powershell
remove-sposite
```
```powershell
remove-spodeletedsite
```
### Change folder permissions
```cmd
takeown /F "full path of folder or drive" /A /R /D Y
```
```cmd
icacls "c:\somelocation\of\path" /q /c /t /grant Users:F
```

### Repair C drive
```cmd
Dism /online /cleanup-image /checkhealth
```
```cmd
dism /online /cleanup-image /scanhealth
```
```cmd
dism /online /cleanup-image /restorehealth
```