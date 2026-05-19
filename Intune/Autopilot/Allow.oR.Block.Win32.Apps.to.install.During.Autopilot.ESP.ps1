$ESP = Get-Process -ProcessName CloudExperienceHostBroker -ErrorAction SilentlyContinue

If ($ESP) 

     {
    
    Write-Host "Windows Autopilot ESP Running"
    
     }
Else {
    
    Write-Host "Windows Autopilot ESP Not Running"
    
     }
