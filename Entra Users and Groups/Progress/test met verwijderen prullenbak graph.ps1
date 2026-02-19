   Connect-MgGraph
   
Import-Module Microsoft.Graph.Identity.DirectoryManagement

   $algemeenGroupName = "algemeen"

    # Probeer de soft-verwijderde Microsoft 365 groep permanent te verwijderen uit Entra ID's prullenbak (via Graph)
    Write-Host "`nControleren en permanent verwijderen van '$algemeenGroupName' uit de Entra ID prullenbak (via Microsoft Graph)..." -ForegroundColor Yellow
    try {
        # NIEUWE CODE: Gebruik Invoke-MgGraphRequest om direct de Graph API aan te roepen voor soft-verwijderde groepen.
        # Dit omzeilt problemen met Get-MgDirectoryObject -DeletedItem.
        $deletedGroupsResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.group" -Headers @{ 'ConsistencyLevel' = 'eventual' } -ErrorAction Stop
        $deletedItems = $deletedGroupsResponse.value # De daadwerkelijke objecten zitten in de 'value' eigenschap van de response

        # Filter de resultaten om de specifieke groep te vinden op DisplayName
        $deletedAlgemeenGroup = $deletedItems | Where-Object { $_.DisplayName -eq $algemeenGroupName } | Select-Object -First 1
        
        if ($deletedAlgemeenGroup) {
            Write-Host "Verwijderde groep '$algemeenGroupName' (ID: $($deletedAlgemeenGroup.Id)) gevonden in Entra ID prullenbak. Permanent verwijderen..." -ForegroundColor Yellow
            Remove-MgDirectoryDeletedItem -DirectoryObjectId $deletedAlgemeenGroup.Id -Confirm:$false -ErrorAction Stop
            Write-Host "Groep '$algemeenGroupName' permanent verwijderd uit Entra ID prullenbak." -ForegroundColor Green
            Start-Sleep -Seconds 10 # Geef tijd voor propagatie
        } else {
            Write-Host "Groep '$algemeenGroupName' niet gevonden in Entra ID prullenbak, mogelijk al permanent verwijderd of niet eerder bestaan." -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Fout bij permanent verwijderen van de groep uit Entra ID prullenbak via Microsoft Graph: $($_.Exception.Message)"
        Write-Warning "Controleer handmatig of de groep en de bijbehorende SharePoint site volledig zijn verwijderd."
    }