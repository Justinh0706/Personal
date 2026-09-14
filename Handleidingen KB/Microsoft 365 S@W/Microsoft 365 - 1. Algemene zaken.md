## Inleiding

Met deze serie van handleidingen kunnen we een compleet netwerk opzetten op basis van **Microsoft 365 Business Premium** (M365 BP). De uitgangspunten zijn:

- Alle Werkplekken en Gebruikers zijn lid van **Entra**
- Alle Werkplek- Applicatie- en Gebruikersinstellingen worden beheerd via **Intune**
- **Autopilot** is waar mogelijk geactiveerd op de werkplekken, zodat deze van afstand opnieuw geïnstalleerd kunnen worden
- Alle gebruikers loggen in met een vorm van MFA. De interne werkplekken zoveel mogelijk met **Windows Hello for Business**, en overige accounts met Passwordless login via **Microsoft Authenticator**.
- Persoonlijke documenten staan in **Onedrive**. Hierop is ook **Known Folder Move** (KFM) actief om de Desktop, Documents en Pictures mappen te redirecten naar **Onedrive**
- Gedeelde documenten staan in **Sharepoint**

Deze handleiding is onderdeel van een serie van handleidingen die betrekking hebben op het inrichten van een **Microsoft 365 Business Premium** omgeving. Je wordt in deze handleidingen naar diverse portalen binnen de Microsoft 365 Cloud verwezen voor beheertaken. 

Deze eerste handleiding behandelt enkele algemene zaken die niet onder een specifiek Microsoft 365 onderdeel vallen.

## Vereisten
- Je hebt Powershell 7 nodig op je werkplek om de scripts van de handleidingen uit te voeren (zie volgende hoofdstuk)
- Alle werkplekken moeten draaien op, of compatible zijn met Windows 11
- Alle werkplekken moeten beschikken over TPM 2.0 chip
- Alle werkplekken moeten voorzien zijn van de meest recente (BIOS/UEFI) firmware en drivers
- Alle accounts moeten voorzien zijn van een Microsoft 365 Business Premium licentie
- Alle DNS records dienen ingesteld te worden zoals deze worden voorgesteld tijdens het koppelen van je eigen domeinnaam. Onder de standaard Exchange records staat een "Advanced" knop waarmee je ook alle records zichtbaar maakt voor o.a. **Intune** en **Mobile Device Management**

## Defender eerste keer opstarten
Microsoft Defender heeft een soort first-run systeem die eerst een keer opgestart moet worden om Defender verder te kunnen configureren. Omdat je vaak erg lang moet wachten op het voltooien hiervan, starten we deze pagina alvast een keer aan het begin van de installatie zodat je er later meteen gebruik van kunt maken. **Het word niet aangeraden om door te gaan met de volgende hoofdstukken zonder deze setup gedraaid te hebben.**

- Open [https://security.microsoft.com](https://security.microsoft.com)
- Kies voor **Endpoints - Configuration Management - Device Configuration**
- Je ziet nu een kopje koffie in beeld, dat is voor nu alles wat we willen doen

## Powershell 7 installeren
Powershell 7 is voor ons nodig om de installatie van de Microsoft Graph modules te installeren zonder foutmelding. Er zit namelijk een limiet in de oudere versies van Powershell om extreem verbruik van geheugen te voorkomen. Omdat de module van Microsoft Graph erg groot is loop je hier dus vaak tegen aan en krijg je de volgende foutmelding: function capacity 4096 has been exceeded for this scope.

Om dit tegen te gaan downloaden en installeren we dus Powershell 7. In Powershell 7 hebben ze deze functie eruit gehaald om ook problemen te voorkomen Zie de bron voor informatie. Om goed gebruik te maken van Powershell 7 kan je het beste Visual studio code downloaden.

Bron: [https://github.com/PowerShell/PowerShell/pull/2363](https://github.com/PowerShell/PowerShell/pull/2363)

##### Installatie
Om Powershell 7 te installeren voor je eerst een aantal commands uit. 

Gebruik $psversiontable om te kijken welke versie je op het moment draait. Is deze versie niet hoger dan 7.0 dan volg je de volgende stappen:

```
winget search --id Microsoft.PowerShell
winget install --id Microsoft.PowerShell --source winget
winget install --id Microsoft.PowerShell.Preview --source winget
```

Hierna staat powershell 7 beschikbaar. Wanneer je in je zoekbalk Powershell 7 opzoekt zie je de terminal. Dit is niet wenselijk aangezien je hier het script dat je gaat uitvoeren niet goed kan doorlezen en ook niet goed kan bewerken. Hiervoor is Visual Studio code erg handig. 

Als je al Visual studio code hebt kan je dit overslaan. 

Ga naar [https://code.visualstudio.com/docs/setup/windows#_install-vs-code-on-windows](https://code.visualstudio.com/docs/setup/windows#_install-vs-code-on-windows) en download de installer (Visual Studio Code on Windows)Wanneer je Visual Studio Code geinstalleerd hebt ga je naar Extensions (CTRL+SHIFT+X) en installeer je de Powershell extensie.

Je bent nu klaar om het script uit te voeren

## Networking (DHCP, DNS)
Omdat een Microsoft 365 Cloud omgeving meestal een lokale server vervangt, is het belangrijk om de DHCP en DNS rollen van de server om te zetten naar de (Watchguard) router. Hoe dit ingesteld moet worden staat in de Watchguard handleiding in deze KB, waarbij de volgende zaken belangrijk zijn om alvast te regelen:

- Verkort de leasetijd op een bestaande DHCP server voor de migratie naar 8 uur. Zo kun je de dag voor de migratie de DHCP omzetten naar de router, zodat alle clients de volgende ochtend hun DHCP en DNS naar de router hebben staan.
- Let goed op een correcte DNS configuratie in de router, zeker als het om een hybride netwerk gaat. Clients moeten het IP adres van de router als hun DNS server gebruiken, en deze moet DNS forwarding ingesteld hebben staan.

## Tenant Onboarding

##### Partnerrelatie (Backoffice)
Dit onderdeel is ter informatie voor onze Backoffice:

Wanneer we een Tenant overnemen die al is ingericht door een andere partij, moeten we nog een partnerrelatie bevestigen namens de klant, zodat de Tenant aan Supracom gekoppeld wordt als Microsoft Partner. Dit gaat niet over GDAP, maar authoriseert Supracom en onze distributeur alleen als leverancier voor licenties.

1. Log in op [https://partner.microsoft.com](https://partner.microsoft.com) en ga naar het **Partner Center**
2. Klik op **Customers** en controleer of de Tenant inderdaad nog niet vermeld staat in de lijst met klanten/tenants
3. Klik op **New Relationship** en kies onze distributeur van Microsoft 365 licenties (Resello/Pax 8)
4. Gebruik de link in een InPrivate venster en log in met de Global Admin van de klant om de aanvraag goed te keuren.

##### Gedelegeerd beheer (GDAP) via CIPP
Om technisch beheer te kunnen uitvoeren vanuit ons Partner account (of CIPP) is het nodig om enkele rechten toe te kennen aan ons als partner. Dit wordt voor nieuwe Tenants meteen ingesteld door onze Backoffice, maar bij overname van bestaande omgevingen kan het nodig zijn om nog zelf te doen.

We vragen onderstaande rechten aan in een Tenant. Deze lijst is overgenomen uit de documentatie van CIPP als aanbevolen rechtengroepen om in te stellen op GDAP [https://docs.cipp.app/setup/gdap/recommended-roles](https://docs.cipp.app/setup/gdap/recommended-roles).

* **Application Administrator**
* **Authentication Policy Administrator**
* **Cloud App Security Administrator**
* **Cloud Device Administrator**
* **Exchange Administrator**
* **Intune Administrator**
* **Privileged Authentication Administrator**
* **Privileged Role Administrator**
* **Security Administrator**
* **SharePoint Administrator**
* **Teams Administrator**
* **User Administrator**
    
##### Tenant onboarden voor GDAP en CIPP beheer

Het is eenvoudiger om deze GDAP relatie in te stellen via CIPP in plaats van via de Microsoft Partner portal. Daarom beschrijven we hier alleen de methode via CIPP.

1. Ga in CIPP naar **Tenant Administration - GDAP Management**
2. Klik op **Add a Tenant**
3. Selecteer de **CIPP Defaults** als GDAP Template en klik op **Add Invites**
4. Open de **Invite** Link nu in een InPrivate venster
7. Ga akkoord met de GDAP aanvraag met behulp van het **Global Admin** account van de klant zelf. Je moet deze pagina soms een keer refreshen om de knop **Next** actief te maken)
8. Open nu in je **normale venster** (dus niet InPrivate) de **Onboarding**. Hiermee wordt de Tenant direct zichtbaar in CIPP om verder te beheren. Dit proces kan een paar minuten duren om alle stappen te doorlopen.

<p class="callout info">Let op: de Global Admin van de klant-tenant zelf blijft altijd nog meer rechten houden dan wij met GDAP instellen. Gebruik 		daarom bij voorkeur tijdens een nieuwe Microsoft 365 Setup het Admin account van de klant zelf. Gedelegeerd beheer is met name bedoeld voor de Servicedesk die via CIPP snel veelvoorkomende handelingen kan uitvoeren.</p>

#### Tenant onboarden in Inforcer
1. Ga in Inforcer naar **Tenants - Partner Center Manager**
2. Ga naar de tenant die je wilt toevoegen en bekijk de **GDAP status en Security group GDAP**. Als dit op Ready staat kan je door naar stap ....
3. Klik achter bij missing roles. Laat hier alles standaard staan en druk op **Create** 
4. Kopieer de link in je browser en log in met de klant tenant om de GDAP relatie toe te staan.
5. Druk nu achter bij Missing roles onder Security group om de missende roles toe te voegen. Assign hier **Inforcer-Onboarding** als groep. 
6. Selecteer de tenant en klik op **Onboard Tenant**

#### Tenant onboarden in Intune Assistant
1. Ga in Intune Assistant naar **Costumer Settings**
2. Ga naar **Add Tenant** en laad alle tenants.
3. Selecteer de tenant die we willen onboarden en geef deze een naam onder **Customer name**. Je kan niet verder zonder deze stap te voltooien. Ga nu verder door op **Provision & Continue** te klikken.
4. Druk op **Start Consent** en accepteer de rechten met je eigen account. 
5. Sluit de onboarding nu af als deze succesvol is geweest. Open nu de tenant en vink de **Assignment Manager** aan.


## MFA inschakelen voor Global Admin

Voordat we MFA inschakelen voor de gehele Tenant, stellen we eerst de juiste MFA methodes handmatig in voor de Global Admin zodat we zeker weten dat we toegang houden nadat we MFA inschakelen voor de gehele tenant. 

- Meld je aan met het Global Admin account in een willekeurig Microsoft portaal
- Ga rechtsboven naar je profiel en kies **View account**
- Kies onder **Security Info** voor **Update Info**
- Configureer een third-party Authenticator App **"I want to use a different authenticator app"**
- Bij de QC code klik je op **"Can't scan image"**
- Kopieer de **Secret Key** en plan deze in het **OTP** veld van Hudu
- Klik vervolgens op **Next** en gebruik de  **OTP** die je opgeslagen hebt in Hudu om de Authenticator in te stellen.

<p class="callout info">Als het niet lukt om een third-party authenticator app te kiezen, controleer dan of **Third-party Software OAUTH Tokens** ingeschakeld is als MFA methode. Dit is wat Hudu gebruikt om een OTP op te slaan. Je kunt dit controleren in Entra onder Protection -> Authentication Methods.</p>

Stel hierna (als je de OTP dus hebt opgeslagen voor de Global Admin) MFA in via het [Microsoft Admin Center](https://admin.microsoft.com) 

- Ga naar **Setup**
- Kies voor **Configure multifactor authentication (MFA)**
- Doorloop de Wizard, en schakel de volgende MFA methodes in:
	- **Microsoft Authenticator App**
	- **FIDO 2 Security Keys**
    - **Third-party software OATH tokens**
	- **Third Party OATH tokens**
    - **Email OTP**
	- **Temporary Access Pass**

Er wordt nu ook gevraagd om alvast Conditional Access Policies aan te maken. Dit kun je gewoon doen, maar ze worden verderop in deze handleiding weer verwijderd omdat we eigen policies gaan aanmaken.

## Koppelen "Custom domainname"

 - Koppel vanuit [https://admin.microsoft.com](https://admin.microsoft.com) de eigen domeinnaam van de klant. Dit kan ook later, maar moet dan op de to-do gezet worden.
 - Maak ALLE DNS records aan die in het overzicht getoond worden in de Admin Portal van Microsoft 365. Zo zijn er voor Intune/MDM bijvoorbeeld ook extra CNAME records nodig voor enterpriseenrollment en enterpriseregistration. 
Hieronder staat een sjabloon om te gebruiken indien je dit door moet sturen naar een externe partij.

```
Deel 1 van de DNS records:

Type: TXT
Name: @
Inhoud: "==VOER HIER DE UNIEKE WAARDE IN VAN HET BETREFFENDE DOMEIN=="


Deel 2 van de DNS records:

Type: MX
Name: @
Inhoud: ==VOER HIER DE UNIEKE WAARDE IN VAN HET BETREFFENDE DOMEIN==

Type: CNAME
Name: autodiscover
Inhoud: autodiscover.outlook.com.

Type: CNAME
Name: enterpriseregistration
Inhoud: enterpriseregistration.windows.net.

Type: CNAME
Name: enterpriseenrollment
Inhoud: enterpriseenrollment-s.manage.microsoft.com.

Type: CNAME
Name: selector1._domainkey
Inhoud: ==VOER HIER DE UNIEKE WAARDE IN VAN HET BETREFFENDE DOMEIN==

Type: CNAME
Name: selector2._domainkey
Inhoud: ==VOER HIER DE UNIEKE WAARDE IN VAN HET BETREFFENDE DOMEIN==

Type: TXT
Name: @
Inhoud: ==VOER HIER DE UNIEKE WAARDE IN VAN HET BETREFFENDE DOMEIN - DENK AAN EVENTUELE BESTAANDE SPF INSTELLINGEN==

Type: TXT
Name: _DMARC

Inhoud voor klanten met serviceovereenkomst:
"v=DMARC1; p=quarantine; rua=mailto:dmarc@supracom.uriports.com; ruf=mailto:dmarc@supracom.uriports.com; fo=1:d:s"

Inhoud voor overige klanten:
"v=DMARC1; p=quarantine;"

```


<p class="callout warning">Houd rekening met SpamExperts en de aangepaste MX records + Exchange Connector die ingesteld moeten worden. Dit staat beschreven in de KB handleiding voor het instellen van Inkomende E-mail Filtering via SpamExperts</p>



## DKIM & DMARC

Om ervoor te zorgen dat e-mail netjes wordt afgeleverd bij de ontvangers, willen wij voor Microsoft 365 Exchange Online DKIM en DMARC activeren. Check hiervoor het DKIM en DMARC gedeelte in de Exchange Online handleiding, maar voer dat nu wel meteen uit om problemen achteraf te voorkomen met het afleveren van e-mail. Ook dit is afhankelijk van het feit of je de eigen domeinnaam van de klant hebt kunnen koppelen of niet. Zo niet, dan zet je het op de to-do van het project.


## Organisatie instellingen

##### Password Expiration Policy

Stel in dat gebruikerswachtwoorden nooit verlopen

- Ga naar [https://admin.microsoft.com/Adminportal/Home?#/Settings/SecurityPrivacy](https://admin.microsoft.com/Adminportal/Home?#/Settings/SecurityPrivacy)
- Ga naar **Settings --> Org Settings --> Security & privacy --> Password Expiration Policy**
- Schakel de optie in om wachtwoorden nooit te laten verlopen

##### Logo instellen voor aanmeldvenster

Om gebruikers duidelijk te laten zien dat ze bij hun vertrouwde organisatie inloggen, en bijvoorbeeld niet op een phishing pagina, stellen we een logo in.

 - Log in bij [https://entra.microsoft.com](https://entra.microsoft.com)
 - Zoek bovenin naar **Company Branding**
 - Edit de pagina, en verander in ieder geval het **Sign-in form -> Banner logo** met een logo in de juiste verhoudingen van de klant (245 x 39 px)
 - Een achtergrond is ook wel fraai, mits de klant daar iets voor beschikbaar heeft. Deze stel je in bij **Basics -> Background image** (1920 x 1080 px)

Dit is een handige online ontwerp tool: [https://www.photopea.com/](https://www.photopea.com/)

 
##### Enable Organization Customization

Voer het volgende Powershell commando uit binnen de tenant van de klant (Niet nodig bij een nieuwe tenant).

~~~powershell
# Installeer de ExchangeOnlineManagement module. Comment deze uit als je de module al hebt
Install-Module –Name ExchangeOnlineManagement -Force

# ExchangeOnlineManagement module importeren
Import-Module ExchangeOnlineManagement

# Verbind met Exchange Online van klant (gebruik Global Admin account van de klant)
Connect-ExchangeOnline

# Exchange OrganizationCustomization inschakelen
Enable-OrganizationCustomization

#Verbinding verbreken
Disconnect-ExchangeOnline
~~~