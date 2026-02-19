Connect-MgGraph

$groupmanagment = Get-MgGroup -Filter "displayName eq 'management schijf'"

if (-not $groupmanagment) {
    Write-Warning "management schijf bestaat niet"
}