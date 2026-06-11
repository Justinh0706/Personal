# Define the admin site URL
$AdminSiteURL = "https://deeznutsnl-admin.sharepoint.com"

# Connect to SharePoint Online
Connect-SPOService -Url $AdminSiteURL

# Get all deleted sites
$deletedSites = Get-SPODeletedSite

# Iterate through the deleted sites and delete them permanently
foreach ($site in $deletedSites) {
  Write-Host "Deleting site:" $site.URL
  Remove-SPODeletedSite -Identity $site.URL -Confirm:$False
}

Write-Host "All deleted sites have been permanently removed."