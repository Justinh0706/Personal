## Voorwaarden
- Bestaande werkplekken moeten de laatste drivers en BIOS hebben
- Alle DNS records moeten aangemaakt zijn. Ook die van "enterpriseenrollment" en "enterpriseregistration", die nodig zijn voor het enrollen van een device bij Intune.

##### Automatic Enrollment
Controleer of alle standaard URL's zijn ingevuld bij de Automatic Enrollment instellingen in Intune. Dit wil bij oudere Tenants nog wel eens ontbreken.

- Ga naar https://intune.microsoft.com
- Kies voor **Devices - Enrollment - Automatic Enrollment**
- Schakel hier de **MDM User Scope** in op **All**
- Controleer of alle standaard URL's zijn ingevoerd of restore deze naar de Default settings

##### DNS Records
Dubbelcheck of de benodigde DNS records voor Intune zijn aangemaakt op de domeinnaam. Gebruik hiervoor de optie **CNAME Validation**

## Deployen van policies
Nu we al het voorwerk hebben gedaan kunnen we alle policies gaan deployen. Dit doen we door middel van Inforcer. Zojuist hebben we in Inforcer een baseline toegepast op de tenant die je wilt gaan voorbereiden. Om die policies te gaan pushen gaan we nu naar Inforcer > Align > Align by Tenant > (Jou tenant) en filter dan op Recommended from baseline. We selecteren hier alle policies en klikken op Align. We krijgen nu een redelijke lijst met opties. Voor alle policies moeten we enkel **Deploy scope tags** aan hebben staan, op de conditional acces policies na. Hier moeten we **Force set policy state** en **Overwrite Policy with the same name** uit hebben staan. Wanneer je dit allemaal geselecteerd hebt gaan we verder. Kijk hier of je alles goed geselecteerd hebt en pas zo nodig aan.

Het duurt ongeveer een uurtje voordat dit allemaal deployed is. Geef het dus even de tijd. Wanneer hij klaar is kijk je goed of alle policies wel deployed zijn. Zo niet deploy je deze nogmaals.

### Assignment (Nog toevoegen)
Dit stuk moet ik nog beschrijven.

##### Optie 1: Autopilot registratie via CIPP (voorkeur)

Via CIPP kunnen we als Microsoft CSP partner Autopilot devices toevoegen aan onze klanttenants. Voorwaarde hiervoor is dat we een bestaande CSP relatie hebben, wat in vrijwel alle gevallen ook zo is omdat Supracom ook de licenties levert.

- Ga in CIPP naar **Intune -> Autopilot - Add Autopilot Device**
- Voer alleen de velden in met **Serial, Manufacturer** en **Model** in. Je kunt eventueel in een andere tenant kijken wat deze waardes precies moeten zijn.

##### Optie 2: Hardware Hash uploaden (alternatief)

Hoewel er dus makkelijkere methodes zijn voor het bekend maken van devices in Autopilot, beschrijven we hier ook de handmatige methode om de hardware hash van een nieuwe Windows PC te uploaden naar je Tenant.

- Schakel de PC in
- Druk op SHIFT + F10
- Start Powershell en voer de volgende commando's uit:

```powershell
Set-ExecutionPolicy Bypass
Install-Script Get-WindowsAutoPilotInfo -Verbose -Force
Get-WindowsAutoPilotInfo.ps1 -Online
```
- Log in met een (Intune) Administrator account van de klant tenant

Wacht nu een minuut of 2-3 totdat het script klaar is. Snel is het niet namelijk. Maar uiteindelijk zie je dit als resultaat:

- Nadat de Hash is geüploaded, kun je in Autopilot de voortgang volgen van de registratie. Wacht met het gebruiken van een Autopilot installatie tot de **Profile status** op **Assigned** staat. Dit kan soms wel een half uur duren.
- Je kunt in Autopilot ook alvast de hostname instellen

## Custom Intune/ADMX policy's
Intune bevat een hele grote collectie met instellingen voor gebruikers en apparaten, die nog steeds groeiend is. Soms kan het zijn dat je een instelling die je binnen AD Group Policy Management wel had, niet kan terugvinden binnen Intune. Voor deze situaties is het mogelijk om ADMX templates te importeren naar Intune, en alsnog toe te passen op gebruikers en werkplekken. Deze functie kun je ook gebruiken om zelf geschreven ADMX templates toe te voegen.

<p class="callout info">Uiteindelijk zijn zowel Intune als Group Policy Management policy's grotendeels gewoon verzamelingen met registerinstellingen die onder HKCU of HKLM toegepast worden op werkplekken. Alles wat je in een Windows Register kunt instellen, kun je ook configureren met Intune of Group Policy.Als het netwerk maar groot genoeg is, loont het vanzelf de moeite om bijvoorbeeld een specifieke applicatieinstellingen via een zelfgeschreven setting uit te rollen</p>

##### Drivemappings (ADMX)
In Intune is het nog niet volledig ondersteund om een drivemapping toe te voegen vanuit een configuration. Hier is wel een omweg voor, ADMX imports. ADMX is een functie die ervoor zorgt dat je zelf functies toe kan voegen in Intune met een soort Powershell script maar dan op XML gebaseerd.
 
- Ga naar **Intune > Devices > Configuration > Import ADMX** en begin een ADMX import.
- Selecteer hier het volgende bestand in het pad: **C:\Windows\PolicyDefinitions\Windows.admx**
- Onder .ADML ga je naar het volgende pad en selecteert het bestand: **C:\Windows\PolicyDefinitions\en-US\windows.aml**
- Ga opnieuw naar **Intune > Devices > Configuration > Import ADMX** en begin een ADMX import.
- Selecteer hier het bestand **Drivemapping.admx** en daarna ook **Drivemapping.adml** uit onze Supracom Github (Onder Microsoft Intune\ADMX)

Wacht tot de synchronisatie klaar is. Wanneer deze klaar is ga je verder naar configurations en maak je een configuration aan als volgt.

- **Create > New policy > Platform: Windows 10 and Later > Profile type: Templates > Imported Administrative templates**.
- Vul hier de naam in, bijvoorbeeld: **Supracom: Drive mapping**
- In **Configuration settings** ga je naar **User Configuration > Network Drive Mappings**
- Selecteer hier de drive letter die wilt gebruiken. Zet deze op de **Enabled** en zet het pad in de policy waar deze naartoe moet verwijzen.
- Voeg de gewenste User-assignments toe en sla alles op. De policy zou nu toegepast moeten zijn wanneer de policy gesynchroniseerd is met de PC.