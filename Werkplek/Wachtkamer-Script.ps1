##---------------------------------------------------------------------------------------------------------------------------##
##                             -->> LEES DIT BLOK GOED DOOR <<-- 
##---------------------------------------------------------------------------------------------------------------------------##
##
## Script:   Wachtkamer Script
## Autor:    Benjamin & Tijmen - Supracom B.V. - Dorpsstraat 15 - Garderen
##
## Alle rechten voorbehouden. Niets uit dit script mag zonder toestemming worden overgenomen.
## Onderstaande variabelen voor dit script moeten aangepast worden naar de klantsituatie.
##
##---------------------------------------------------------------------------------------------------------------------------##
##                             -->> LEES DIT BLOK GOED DOOR <<--
##---------------------------------------------------------------------------------------------------------------------------##

##---------------------------------------------------------------------------------------------------------------------------##
## Variables:
##---------------------------------------------------------------------------------------------------------------------------##

$ProgramDir = '\\srv-02\apps$\Exquise\'
$ProgramExec = "$ProgramDir\exquisewachtkamer.exe"
$ProgramOverlay = "$ProgramDir\exquisewachtkameroverlay.exe"

##---------------------------------------------------------------------------------------------------------------------------##
## Don't change anything below
##---------------------------------------------------------------------------------------------------------------------------##

Add-Type -AssemblyName PresentationFramework

## Write status
write-host 'We starten de wachtkamer module..'

## Start-Sleep & Ping
start-sleep -seconds 5
Ping srv-02.ad.kliniekhelder.nl

## Start Wachtkamer Module
Try {
  start-Process -FilePath $ProgramExec -WorkingDirectory $ProgramDir -WindowStyle Maximized
}

## Wachtkamer Module kan niet worden gestart
catch {
  [System.Windows.MessageBox]::Show('De wachtkamer software kan niet worden gestart. Controleer uw netwerk verbinding en herstart daarna uw computer. Druk op OK om verder te gaan')
  ncpa.cpl
  Exit
}

## Start-Sleep
start-sleep -seconds 5

## Write status
write-host "We stoppen geforceerd 'Explorer.exe'.."

## Stop Explorer
taskkill /F /IM explorer.exe

## Start-Sleep
start-sleep -seconds 5

## Write status
write-host 'We starten de wachtkamer overlay module..'

## Start Wachtkamer Overlay
start-Process -FilePath $ProgramOverlay

## Start-Sleep
start-sleep -seconds 5

## Write status
write-host "Finish!"

## Start-Sleep
start-sleep -seconds 5