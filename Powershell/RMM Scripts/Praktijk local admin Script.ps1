# Controleer of het systeem een domain controller is
$isDomainController = (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).DomainRole -eq 5

if (-not $isDomainController) {
    # Systeem is geen domain controller, exit met code 0
    Write-Output "Skipped: Dit systeem is geen AD domaincontroller."
    exit 0
}

# Groepen die gecontroleerd moeten worden
$groupNames = @("Praktijk Local Admin", "Roles-LocalAdmin", "General-General-Local-Admin")

# Exclude logon names starting with ADM
$excludedPrefix = "adm_"

# Functie om leden van een groep te controleren
function Check-Group {
    param (
        [string]$groupName
    )

    # Gebruik try-catch om fouten af te vangen en geen foutmeldingen te tonen
    try {
        # Controleer of de groep bestaat
        $groupExists = Get-ADGroup -Identity $groupName -ErrorAction Stop

        if ($null -eq $groupExists) {
            # Groep bestaat niet, log dit en sla deze groep over
            Write-Output "Informatie: De groep '$groupName' bestaat niet en wordt overgeslagen."
            return $false
        }

        # Eerst controleren op DIRECTE leden (gebruikers EN groups)
        $directMembers = Get-ADGroupMember -Identity $groupName -ErrorAction Stop

        if ($null -eq $directMembers -or $directMembers.Count -eq 0) {
            # Geen leden in de groep
            Write-Output "Informatie: Geen leden gevonden in de groep '$groupName'."
            return $false
        }

        # Check directe security groups
        foreach ($member in $directMembers) {
            if ($member.objectClass -eq "group") {
                # Detecteer directe security groups die lid zijn van de groep
                Write-Output "FOUT: Security group '$($member.Name)' gevonden in groep '$groupName'."
                return $true
            }
        }

        # Nu controleren op alle eindgebruikers (recursief)
        $recursiveMembers = Get-ADGroupMember -Identity $groupName -Recursive -ErrorAction Stop

        # Check alle eindgebruikers (recursief)
        foreach ($member in $recursiveMembers) {
            if ($member.objectClass -eq "user") {
                # Vergelijk niet-hoofdlettergevoelig door .ToLower() te gebruiken
                if (-not $member.SamAccountName.ToLower().StartsWith($excludedPrefix.ToLower())) {
                    Write-Output "FOUT: Lid '$($member.SamAccountName)' in groep '$groupName' begint niet met '$excludedPrefix'."
                    return $true
                }
            }
        }

        # Als we hier zijn, zijn er geen leden die de criteria schenden
        Write-Output "OK: Geen leden in de groep '$groupName' die niet beginnen met '$excludedPrefix'."
        return $false
    }
    catch {
        # Fout afvangen zonder deze weer te geven
        Write-Output "Informatie: De groep '$groupName' bestaat niet of kan niet worden opgehaald en wordt overgeslagen."
        return $false
    }
}

# Loop door de groepen om te controleren
$hasInvalidMembers = $false

foreach ($groupName in $groupNames) {
    $result = Check-Group -groupName $groupName

    if ($result -eq $true) {
        $hasInvalidMembers = $true
    }
}

Clear-Host

# Exitcode bepalen
if ($hasInvalidMembers) {
    # Exit met code 1 als er leden zijn die niet beginnen met "adm_"
    Write-host "FOUT, er zijn leden gevonden in de local admin groep"
    exit 1
} else {
    Write-host "OK: Er zijn geen leden gevonden in de local admin groep" 
    
    exit 0
}