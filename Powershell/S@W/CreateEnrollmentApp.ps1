# Connecting with the required permissions
Connect-MgGraph -Scopes 'Application.ReadWrite.All'

$intuneEnrollmentAppUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq 'd4ebce55-015a-49b5-a083-c84d1797ae8c'"
$intuneEnrollmentAppExists = [bool](Invoke-MgGraphRequest -Method GET -Uri $intuneEnrollmentAppUri -ContentType 'PSObject' -OutputType PSObject).value.Count -gt 0

# If not exist, we create it
if (-not $intuneEnrollmentAppExists) {

    $body = @{ appId = 'd4ebce55-015a-49b5-a083-c84d1797ae8c' } | ConvertTo-Json   

    $null = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body $body -ContentType 'application/json'
    Write-Host -ForegroundColor Green 'Microsoft Intune Enrollment created'
}
else {
    Write-Host -ForegroundColor Green 'Microsoft Intune Enrollment already exists'
}