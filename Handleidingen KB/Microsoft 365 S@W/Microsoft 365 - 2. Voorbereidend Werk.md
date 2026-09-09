## Voorwaarden
Voordat je met dit hoofdstuk begint, dient eerst deel 1 van de Microsoft 365 handleiding uitgevoerd te zijn.

## Voorwerk voor je begint met het klaarmaken van de Tenant
Hier beginnen we met het voorbereidende werk zodat we zometeen alle configuration policy's, Conditional acces policy's en compliance policy's kunnen gaan deployen.

Er zijn een aantal zaken nodig om dit te deployen. In de policy's zitten namelijk assignments filters en groupen vewerkt. Zonder deze groepen en filters zullen alle assignments falen omdat deze niet aanwezig zijn. We starten eerst met het assignen van de baseline aan de tenant die we gaan opzetten in Inforcer. 

Ga naar Inforcer en kies voor Align > Baseline > SAW - Full Baseline > Edit > Aligned tenants en zet een vinkje bij de tenant die we opzetten en klik op save. De full baseline is handig om te gebruiken als je alles wilt gaan deployen in 1 keer. De partial baselines zijn uiteindelijk wel handiger om te gebruiken omdat je problemen hier makkelijk mee kan troubleshooten. Het maakt uiteindelijk niet heel veel uit welke je gebruikt.

### Hernoemen oude policy's (Enkel bij bestaande Microsoft 365 omgeving.)
Eerst zorg je dat alle assignments nagekeken zijn. Hiervoor gebruik je de Intune Assistant (Assignments > Configuration Assignments (All)). Hernoem de oude policy’s naar _LEGACY – zodat deze herkend worden in de intuneops tool die aanleverd is door SAW. Nergens mag All devices staan en moet dit omgezet worden naar een groep.

### Assignment filters
Gebruik nu de maccy tool om de assignment filters te exporteren en weer te importeren in de tenant. De link naar de download valt te vinden in onze Projecten sharepoint onder General > Bestanden > Secure at work > Maccy Tool. Verbind nu met de baseline tenant (Credentials zijn beschikbaar onder de Supracom Tenant in Hudu). Ga naar Filters en exporter alle assignment filters. **Vergeet niet Export Assignments uit te vinken**. Wanneer je dit gedaan hebt kan je verbinden met de andere tenant en importeer je de filters die je net geexporteerd hebt. Vink hier ook de import Assignments uit.

### Groepen
Om de groepen te deployen gebruiken wij Inforcer en een script dat is aangeleverd door S@W. We zijn nu nog gelimiteerd om 2 tools te gebruiken omdat Inforcer het deployen van Nested Groups nog niet ondersteund. Het script gebruiken we nu om die nested groups de juiste assignments te geven.

Eerst gaan we naar Inforcer, en ga hier naar de Baseline Tenant > Groups. Rechts bovenin klikken wij op Deploy Groups en scrollen we eerst helemaal naar beneden. Dit doen we omdat anders niet alle groepen geselecteerd worden. Selecteer alle groepen behalve de Microsoft 365 groepen en selecteer hierna je tenant waar je het wilt deployen. De groepen zijn nu deployed.

Nu kunnen we de Nested Groups assignen. Het script samen met de CSV is beschikbaar onder de Projecten Sharepoint General > Bestanden > Secure at Work > Nested Group Script > NestedGroupMembership-GUI. Wanneer je deze gestart hebt kunnen we na gaan denken welke optie wij willen kiezen. Je hebt namelijk 3 opties, "All (No Phase filtering)" kunnen we gebruiken om een report te maken van de huidige omgeving. Die zal in eerste instantie toch nog geen assignments hebben dus hoeven we deze nog niet te draaien. De optie "Building" gebruiken we in het geval van een bestaande omgeving die nog steeds beheerd word door de oude tenant. Dit zorgt er namelijk voor dat de Autopilot assignments nog niet gedaan worden, wat er uiteindelijk voor zorgt dat wij nog geen zorg hierover dragen. Normaal gesproken hoeven wij ons hier niet druk over te maken.

In dit geval gaan we ervan uit dat we een "Greenfield" tenant hebben. Connect eerst met de tenant die we gaan opzetten. Gebruik de optie "Done (Customer fully rolled out)" en onder What to do vinken we apply (make changes) en Create missing groups aan. Run hierna het script en wacht tot alle assignments gedaan zijn.

