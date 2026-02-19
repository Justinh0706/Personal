# Wait 
Start-Sleep -Seconds 1

# Rename Local Admin Account to Supradmin
$admin = [ADSI]"WinNT://./Administrator,user"
$admin.psbase.rename("Supradmin")

# Enable and set password for Supradmin
Invoke-Command { net user Supradmin "@PraktijkBeheer" /active:yes }

# Wait
Start-Sleep -Seconds 1

Exit