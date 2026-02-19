# Sluit het Startmenu als het open is
$startMenuProcess = Get-Process -Name "StartMenuExperienceHost" -ErrorAction SilentlyContinue
if ($startMenuProcess) {
    Startmenu-Process -Name "StartMenuExperienceHost" -Force
}

Exit