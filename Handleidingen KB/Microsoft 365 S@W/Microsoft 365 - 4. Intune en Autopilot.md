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

## Users toevoegen aan groepen
Voordat we beginnen is het absoluut essentieel dat er bepaalde users al lid zijn van bepaalde groepen. Als we namelijk de conditional acces policies gaan deployen moeten we de Global admin excluden hiervan door deze lid te maken van de groep **AAD_UA_ConAcc-Breakglass**. Dit zorgt ervoor dat conditional acces policies niet deployed worden op de global admin. Dit kunnen we dan later 1 voor 1 excluden. **Dit nog verder uitschrijven hoe we dit gaan inzetten**

## Deployen van policies
Nu we al het voorwerk hebben gedaan kunnen we alle policies gaan deployen. Dit doen we door middel van Inforcer. Zojuist hebben we in Inforcer een baseline toegepast op de tenant die je wilt gaan voorbereiden. Om die policies te gaan pushen gaan we nu naar Inforcer > Align > Align by Tenant > (Jou tenant) en filter dan op Recommended from baseline. We selecteren hier alle policies en klikken op Align. We krijgen nu een redelijke lijst met opties. Voor alle policies moeten we enkel **Deploy scope tags** aan hebben staan, op de conditional acces policies na. Hier moeten we **Force set policy state** en **Overwrite Policy with the same name** uit hebben staan. Wanneer je dit allemaal geselecteerd hebt gaan we verder. Kijk hier of je alles goed geselecteerd hebt en pas zo nodig aan.

Het duurt ongeveer een uurtje voordat dit allemaal deployed is. Geef het dus even de tijd. Wanneer hij klaar is kijk je goed of alle policies wel deployed zijn. Zo niet deploy je deze nogmaals. Een veel voorkomende fout is wel een Conditional acces policy die niet wilt deployen. Om precies te zijn is dat CAD019-Intune: Require MFA and set sign-in frequency to every time-v1.0. In de tenants mist er soms een enterprise application waardoor de policy niet deployed kan worden. Hiervoor is een script beschikbaar gezet in onze Github (CreateEnrollmentapp.ps1). Draai eerst dit script en start hierna de deployment van de policy opnieuw.

### Uitleg Additional Settings

#### Conditional Acces

**Force set policy state**
De force set policy state onder Conditional acces hoeft niet perse aan aangezien deze altijd al op **report-only** staan vanuit de baseline tenant. Dit hoeven we niet af te dwingen. 
**Overwrite policy with same name at destination tenant?**
Overwrite Policy with same name at destination tenant willen we ook niet aan hebben staan omdat dat niet nodig is. Dit zorgt ervoor dat oude policies niet overschreven worden.  
**Deploy group and directory role assignments?**
Deze moet **Altijd** aanstaan. Dit zorgt er namelijk voor dat de exclusions aangemaakt worden voor de breakglass en global admin accounts. Zonder dat deze deployed worden zal je jezelf uitsluiten van de tenant omdat er geen exclusions zijn aangemaakt.
**Deploy location assignments?**
Er zijn Conditional acces policies die vereisen dat je MFA enkel mag registreren vanuit een trusted location. Als de location assignments niet deployed zijn kan je dus geen MFA registreren waardoor je uitgesloten word van je tenant. 
**Deploy non-standard cloud application assignments?**
Dit vinkje is nodig voor een exclusion voor de Intune autopilot registratie. 
**Deploy authentication assignments?**
Dit neemt mee of een policy de authentication strenght meeneemt in een policy zoals bijvoorbeeld phishing resistant MFA afdwingen.

## Assignment
Om de assignments toe te voegen hebben we een aantal zaken te regelen. We hebben eerst de CSV file nodig van S@W. Hier staan alle assignments in die we nodig hebben om de configuration policies te assignen aan een groep. Ook moeten we de klant onboarden in Intune Assistant. 

Eerst gaan we naar Intuneassistant.cloud. Hier log je in met je account en ga je uiteindelijk naar customer setting (Functie word beschikbaar als je met je muis op je account staat). Hier gaan we naar add tenants > load tenants. Voeg hier de tenant toe en accepteer de app registration met jou GDAP account (Eigen account). Hierna kunnen we assignment manager toepassen op de tenant. Dit doen we door de tenant te editten en Assignment manager op enabled te zetten. Hierna kunnen we beginnen met de assignments.

Om de assignments uit te voeren moeten we in de "context" werken van de klant tenant. Om in die context te werken editen we de klant weer onder customer settings en zetten we de tenant als context. 

Als de klant een bestaande Microsoft 365 omgeving heeft moeten we deze eerst inspecteren voor assignments op all devices/all users. Dit doen we omdat deze niet excluded kunnen worden, deze moeten op een groep komen te staan zodat de exclusions zouden kunnen maken zo nodig. Dit kunnen we doen door naar Assignments > configuration policies te gaan. Inspecteer hier of alles juist staat. Deze stap kan je overslaan als dit een greenfield tenant is.

Om de assignments uit te voeren gaan we naar Assignment manager > Intune Assignments. Hier importeren we nu de CSV die aangeleverd is. Deze valt de vinden onder onze Projecten sharepoint onder General > Bestanden > Secure at Work. Hier zie je nu alle assignments die hij heeft opgehaald uit de CSV. Deze kunnen we nu vergelijken met de tenant zijn assignments, druk hiervoor op Compare rows, kijk nu even goed wat of er iets mis is gegaan. Het kan zijn dat er policies missen of dat de CSV outdated is, let hier even goed op en controleer dit goed. Mocht alles correct zijn klikken we op select all en starten we de migratie. Wanneer deze klaar is kunnen we een verificatie doen van de assignments. Dit doen ze omdat Microsoft Graph soms false positives kan geven omdat de module gewoon simpelweg loom is. Alle assignments zijn nu gedaan!

**Let op!!! Wanneer Intune Assistant vraagt om admin consent voor de applicatie wanneer je de assignments wilt toevoegen moet je inloggen met de link met je global administrator!**

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