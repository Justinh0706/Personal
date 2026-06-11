Deze handleiding is onderdeel van een serie van handleidingen die betrekking hebben op het inrichten van een Microsoft 365 Business Premium omgeving. Je wordt in deze handleidingen naar diverse portalen binnen de Microsoft 365 Cloud verwezen voor beheertaken. 

## Nog verwerken
- Phishing Resistant MFA CA policy voor Service Providers (testen). Om toegang vanuit Supracom Partner Tenant richting klant tenants altijd Phishing Resistant MFA te vereisen. Nu worden Service Providers nog expliciet uitgesloten in de standaard MFA policy bij klanten
- Web Sign In inschakelen op werkplekken (eerst testen Supracom Tenant)
- Self Service Password Reset standaard inschakelen (SSPR)
- NFC FIDO inloggen op ondersteunde applicaties (Exquise Next Gen, Aivory)

## Changelog

- 17-12-2025: Handleiding review met diverse aanpassingen
- 20-03-2026: Hoofdstuk Global Secure Access toegevoegd


## Voorwaarden
Voordat je met dit hoofdstuk begint, dient eerst deel 1 van de Microsoft 365 handleiding uitgevoerd te zijn.


## Aanmaken accounts
Maak alle gebruikersaccounts aan. Shared (generieke) accounts beveiligen we met een complex "Horse-Battery-Staple" wachtwoord, die we via Windows Hello for Business voorzien van een pincode op de werkplekken. 

- Leg een werkplek wachtwoord vast in IT Glue
- Leg ook een aparte werkplek pincode vast in IT Glue


<p class="callout info">Het werken met pincode authenticatie via Windows Hello for Business is veiliger, en gebruiksvriendelijker. Deze aanmeldmethode wordt ook gezien als Phishing Resistant MFA, waardoor we gedeelde werkplekken niet hoeven uit te sluiten van MFA Conditional Access Policy's</p>

<p class="callout warning">Indien er sprake is van Entra Cloud Sync vanuit een lokale Active Directory, dan maak je de gebruikers en Assigned groepen niet aan in Entra, maar via AD. Onderstaand script is in dat geval ook NIET te gebruiken.</p>

##### Gedeelde gebruikersaccounts

**Powershell script voor aanmaken gebruikers (Alleen Entra)**

Download het script in onze Github. Gebruik hiervoor de Supracom-Script-downloader. Ook kan je hem online downloaden in onze Github. Mocht je nog geen toegang hebben tot onze repository vraag dit dan even aan Matthijs of Justin.

https://github.com/Supracom/Supracom/blob/master/Microsoft%20Entra/Entra%20Users%20and%20Groups.ps1

##### Persoonlijke accounts
Maak nu ook alle persoonlijke accounts aan. Dit zijn meestal accounts voor een tandarts/eigenaar en de praktijkmanager. Deze accounts krijgen hun eigen persoonlijke wachtwoord.



## Aanmaken groepen
Als het goed is zijn de groepen aangemeld volgens de volgende tabel. Controleer of dit juist is en controleer of de licenties gekoppeld zijn aan de groepen.


| Naam                         | Type          | Status   		| Leden                                     | Licenties                      |
| ---------------------------- | ------------- | -------------- | ----------------------------------------- | ------------------------------ |
| Users-Email                  | Security      | Assigned 		| *Alle mail-only accounts*                 |          				         |
| Users-Shared                 | Security      | Assigned 		| *Alle generieke accounts*                 |                                |
| Users-Personal               | Security      | Assigned 		| *Alle persoonlijke accounts*              |                                |
| Users-AllUsers               | Security      | Dynamic User*	| Zie Syntax 2							    |                                |
| License-BusinessPremium      | Security      | Assigned		| *Alle gebruikers die een licentie hebben* | Microsoft 365 Business Premium |
| License-ExchangeOnline       | Security      | Assigned 		| *Alle postvakken die een licentie hebben* | Exchange Online (Plan 1)       |
| Application-Microsoft365     | Security      | Assigned 		| License-BusinessPremium                   |                                |
| Devices-EntraJoined          | Security      | Dynamic Device*| Zie Syntax 1 							    |                                |
| Devices-Autopilot            | Security      | Dynamic Device*| Zie Syntax 3					     	    |                                |
| Devices-Managed              | Security      | Dynamic Device*| Zie Syntax 4					     	    |                                |
| Algemeen                     | Microsoft 365 | Dynamic User*  | Zie Syntax 2          				    |                                |
| Management                   | Microsoft 365 | Assigned  		| *Alle persoonlijke accounts van managers* |                                |
| Roles-RDPEnabled             | Security      | Assigned   	|                                           |                                |
| Roles-LocalAdmin**           | Security      | Assigned   	|                                           |                                |

*: Dit zijn de syntaxen om te gebruiken voor de dynamische groepen
<br></br>
**: Let op dat je deze groep aanmaakt met de optie "Entra Roles can be assigned to this group"" ingeschakeld!


Syntax 1: Devices-EntraJoined  (Alle Entra Joined en Hybrid Joined Devices. 
Met andere woorden, alleen Company-Owned (Corporate) devices, en dus geen Registered devices wat meestal persoonlijke devices zijn)
 
```
(device.deviceTrustType -eq "AzureAD") -or (device.deviceTrustType -eq "ServerAD")
```

Syntax 2: Alle gebruikers (Alle Members in de tenant, maar geen Guest accounts)

```
(user.objectId -ne null) and (user.userType -eq "Member")
```

Syntax 3: Devices-Autopilot

```
(device.devicePhysicalIDs -any (_ -startsWith "[ZTDid]"))
```

Syntax 4: Devices-Managed

```
(device.displayName -startsWith "SID-")
```


## Groepen instellen
Nu moeten we de leden nog toevoegen aan alle relevante groepen. Controleer in ieder geval de onderstaande groepen:

- **Users-Email**: Voeg alle mail-only accounts aan deze groep
- **Users-Shared**: Controleer of alle gedeelde accounts lid zijn van deze groep
- **Users-Personal**: Maak alle persoonlijke accounts lid van deze groep
- **License-BusinessPremium**: Voeg alle accounts toe die een Microsoft 365 Business Premium licentie krijgen (meestal alle Shared + Personal accounts)
- **License-ExchangeOnline**: Voeg alle mail-only accounts aan deze groep
- **Management**: Voeg alle management accounts toe aan deze groep

**Checklist aanmaken gebruikers en groepen**
- Verwijder na het aanmaken van de standaard lijst met gebruikers meteen alle gebruikers die niet van toepassing zijn.
- Maak de persoonlijke accounts handmatig aan
- Controleer of alle groepen die aangemaakt zijn, overeenkomen met de bovenstaande tabel
- Controleer of de licenties daadwerkelijk zijn gekoppeld aan de groepen, en dus ook de betreffende Members van die groepen

## Applicaties goedkeuren
Er zijn een aantal Enterprise Applications die we standaard alvast goedkeuren voor de gebruikers;

- Apple Accounts (voor IOS Mail App): [https://aka.ms/ConsentAppleApp](https://aka.ms/ConsentAppleApp)



## Local Administrator Settings
Binnen Entra zijn diverse instellingen van toepassing met betrekking op lokale Administrator rechten. We gaan een groep aanmaken die op alle werkplekken lokale Administrator rechten krijgt, en we leggen uit hoe je een specifiek account permanent instelt als lokale beheerder. Daarnaast activeren we ook LAPS zodat Admin wachtwoorden geroteerd worden, en opgevraagd kunnen worden in Entra.


### Microsoft Entra Local Administrator Password Solution (LAPS) inschakelen
Voordat we met Intune LAPS kunnen configureren, moeten we dit eerst voor de Tenant inschakelen via Entra.

- Ga naar [https://entra.microsoft.com](https://entra.microsoft.com)
- Ga naar **Devices -> Overview -> Device Settings**
- Schakel de optie in bij **Enable Microsoft Entra Local Administrator Password Solution (LAPS)**


### Gebruiker niet standaard Local Admin maken
Standaard krijgt de gebruiker die een computer Entra-Joined, automatisch lokale Administrator rechten. Dit willen wij niet, dus schakelen we dit centraal uit.

- Ga naar [https://entra.microsoft.com](https://entra.microsoft.com)
- Ga naar **Devices -> Overview -> Device Settings**
- Zet de optie op **None** bij **Registering user is added as local administrator on the device during Microsoft Entra join**


### Global Admin accounts automatisch Local Admin maken
- Ga naar [https://entra.microsoft.com](https://entra.microsoft.com)
- Ga naar **Devices -> Overview -> Device Settings**
- Schakel de optie in bij **Global administrator role is added as local administrator on the device during Microsoft Entra join**


### Gebruikers toevoegen aan de lokale Administrators groep
Soms is het nodig om een gebruiker lid te maken van de lokale Administrator groep. Met een Entra Joined werkplek kun je dit doen middels het volgende commando. Vervang "Rontgen1" met de juiste gebruikersnaam (AzureAD is wel altijd hetzelfde)

```
net localgroup administrators AzureAD\Rontgen1 /add
```


## Authentication methods (voorheen MFA settings)

In een Conditional Access Policy kun je 3 verschillende groepen MFA kiezen, waarvan **Require multifactor authentication** de meest universele MFA implementatie is. **Passwordless MFA** en **Phishing Resistant MFA** zijn de meer striktere en veiligere opties.

We gaan nu de Authentication Policy instellen:

- Ga naar de **Entra** portal via [https://entra.microsoft.com](https://entra.microsoft.com)
- Kies voor **Authentication methods**
- Schakel de volgende Authentication Methods in
- Ga naar **FIDO2 security key** - **Enabled:** Yes - **include:** All Users
- Ga naar **Microsoft Authenticator** - **Enabled:** Yes - **include:** All Users - **Authentication mode:** Any
- Ga naar **SMS Message** - **Enabled:** No - **include** All Users
- Ga naar **Temporary Access Pass** - **Enabled:** Yes - **include** All Users
- Ga naar **Hardware OATH tokens** - **Enabled:** Yes - **include** All Users
- Ga naar **Third-party Software OATH** - **Enabled:** Yes - **include** All Users
- Ga naar **Email OTP** - **Enabled:** No - **include** All Users
- Ga naar **Voice Call** - **Enabled:** No - **include** All Users
- Ga naar **Certificate-Based Authentication** - **Enabled:** No - **include** All Users
- Ga naar **QR Code** - **Enabled:** No - **include** All Users

Je hebt nu in totaal 5 authenticatie methodes ingeschakeld voor alle gebruikers.

##### Legacy MFA uitschakelen
Controleer of de Legacy MFA voor deze tenant al is uitgeschakeld.

- Kies voor **Multifactor Authentication**
- Ga onder het kopje **Getting started** naar **Additional cloud-based multifactor authentication settings**
- Klik bovenin op **Service Settings**
- Schakel alle opties uit onder **Verification options** en haal eventuele IP uitzonderingen er ook uit
- Ga in Entra weer naar **Protection --> Authentication methods**
- Kies nu voor **Manage Migration** en voltooi de migratie


## Temporary Access Passwords (TAP)
Omdat accounts tegenwoordig standaard beveiligd zijn met MFA, is incidentele toegang voor een beheerder of voor een nieuwe medewerker niet mogelijk zonder dat degene met de MFA er ook bij aanwezig is. Hier zijn TAP wachtwoorden voor te gebruiken, die eenmalig of een beperkte tijd gebruikt kunnen worden als een tijdelijke Bypass MFA inlogmethode.

Wij gebruiken als beheerder TAP wachtwoorden vooral om eenmalig te kunnen inloggen met een account zonder MFA. Het genereren van een TAP wachtwoord kan ook eenvoudig via **CIPP**

De manier waarop Microsoft het gebruik van TAP ziet is:

1. Je maakt een nieuw gebruikersaccount aan met een complex wachtwoord
2. Via Conditional Access is MFA afgedwongen op alle accounts, maar dit nieuwe account moet deze nog registreren
3. Je verstrekt een TAP wachtwoord aan de nieuwe gebruiker, die eenmalig te gebruiken is
4. De gebruiker gaat naar [https://aka.ms/mfasetup](https://aka.ms/mfasetup) en wordt direct om zijn TAP gevraagd
5. Na het inloggen registreert de gebruiker direct zijn MFA onder Security Info

Zoals je ziet is het daadwerkelijke wachtwoord van dit account op deze manier nooit nodig geweest, en ook niet uitgewisseld.


## Conditional Access

Conditional Access is een fundamenteel onderdeel van een goed beveiligde Azure omgeving.
Belangrijk om te weten over CA policies is dat je voor elk scenario een policy moet hebben. Exclude je bijvoorbeeld een groep gebruikers uit de eerste policy, dan moet je nog een andere policy hebben die deze groep expliciet wél behandelt. Vereis je MFA in een policy én moet het device compliant zijn, dan moet er ook een policy zijn die dit vereist voor non-compliant devices. Als er geen match is voor een gebruiker/groep/locatie, dan heeft dat account vrij toegang tot Azure zonder MFA of andere extra beveiliging.<br></br>

We maken een standaard CA policy aan die alle verbindingen beveiligt met MFA, behalve die vanuit vertrouwde locaties. Ook sluiten we bepaalde accounts uit die gebruikt worden voor Directory Synchronization, of die op een andere manier beveiligd worden met MFA.

Daarnaast maken we nog een extra CA policy aan die de registratie van MFA methodes beperkt tot alleen vertrouwde locaties. Dit maakt het voor een hacker onmogelijk om een eigen MFA methode te koppelen aan een account.


### Security Defaults uitschakelen

Voordat je Conditional Access Policy's kunt aanmaken, moet je eerst controleren of Security Defaults uitgeschakeld is.

- Ga naar [https://entra.microsoft.com](https://entra.microsoft.com)
- Ga onder **Identity** naar **Overview**, en kies dan voor het tabblad **Properties**
- Onderaan zie je de optie om Security Defaults uit te schakelen


### Conditional Access Policy's aanmaken

Conditional Access policies zijn ook te beheren via CIPP. Dit heeft ook de voorkeur omdat het de kans op fouten verkleint, en we via CIPP deze policies in de toekomst ook willen afdwingen. Toch beschrijven we de instellingen zoals je ze handmatig zou aanmaken, zodat duidelijk is wat we precies instellen.


<p class="callout warning">Wanneer je Conditional Access policy's aanmaakt in een bestaande Tenant die in gebruik is, bedenk dan goed wat de impact is van deze nieuwe policy's in de huidige omgeving! Eventueel kun je ze ook in Reporting Only mode aanmaken, om op de dag van de installatie te kunnen inschakelen. Borg dit soort zaken altijd in een to-do op het project</p>


### Named Locations
We beginnen met het instellen van de Named Locations. Standaard stellen we deze in op de locatie van de klant en het kantoor van Supracom.

- Ga naar de **Entra** portal via [https://entra.microsoft.com](https://entra.microsoft.com)
- Kies voor **Protection --> Conditional Access**
- Voeg een **Named Location** toe op basis van een IP-Adres
  - **Name:** Straatnaam van de klant
  - **IPv4:** IP-Adres van de klant (/32)
  - **Mark as trusted location:** Enable


### Policy's aanmaken
We gaan in totaal 4 Conditional Access Policy's aanmaken.

Verwijder de bestaande Conditional Access Policies (controleer wel of deze misschien eerder zijn aangemaakt met specifieke redenen)

##### Supracom: Block unmanaged devices
- Maak een nieuwe Policy aan met de naam **Supracom: Block unmanaged devices**
  - **Users - Include:** All users
  - **Users - Exclude:**
    - Directory Roles: Directory Synchronization Accounts, Global Administrators
    - Guest or external users: Service Provider Users, Selected Tenant ID "4e473cc9-b4a3-42de-980a-5594e0d7a277"
    - **Target Resources:** Resources -> All Resources
  - **Network - Include:** Any network or location
  - **Network - Exclude:** All trusted networks and locations
  - **Conditions - Filter for devices:**
    - Devices matching the rule: Exclude from policy
    - Add Expression: TrustType Equals **Microsoft Entra Joined** OR **Microsoft Entra Hybrid Joined** OR **Microsoft Entra Registered**
  - **Grant** --> Block Access
- **Enable policy:** On
- **Save**

##### Supracom: Require MFA for All Users - Exclude Trusted Locations
- Maak een nieuwe Policy aan met de naam **Supracom: Require MFA for All Users - Exclude Trusted Locations and Service Providers**
  - **Users - Include:** All users 
  - **Users - Exclude:**
    - Directory Roles: Directory Synchronization Accounts
    - Guest or external users: Service Provider Users, Selected Tenant ID "4e473cc9-b4a3-42de-980a-5594e0d7a277"
  - **Target Resources:** Resources -> All Resources
  - **Network - Include:** Any network or location
  - **Network - Exclude:** All trusted networks and locations
  - **Grant** --> Grant access - Require authentication strength - Multifactor Authentication
- **Enable policy:** On
- **Save**

##### Supracom: Restrict MFA Registration to TAP
- Maak een nieuwe Policy aan met de naam **Supracom: Block MFA Registration**
  - **Users - Include:** All users
  - **Users - Exclude:** All guest and external users (alles aanvinken)
  - **Target Resources:** User Actions -> Register security information
  - **Network - Include:** Any network or location
  - **Network - Exclude:** All trusted networks and locations
  - **Grant** --> Grant access - Require authentication strength - Multifactor Authentication
- **Enable policy:** On
- **Save**

<p class="callout info">Bovenstaande MFA Registration Policy is aangepast naar aanleiding van Microsoft artikel https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-all-users-security-info-registration </p>

##### Block Legacy Authentication
- Deploy een nieuwe Policy vanuit "**New policy from template**"
  - Kies "**Block legacy authentication**"
  - Haal de huidige gebruiker weg uit de exclusions. We willen echt alle Users beveiligen met MFA
  - Schakel de policy in
 
**==Checklist Conditional Access==**
- Staan alle CA Policies ingeschakeld, en niet in Reporting Only Mode?
- Zijn er geen exclusions gemaakt voor Admin gebruiker die je hebt gebruikt om deze in te stellen?
- Is het kantoor Supracom uitgeschakeld als Trusted Location?

## Entra Cloud Sync
Bij het gebruik van het laatste PS script staat de **Microsoft Entra Provisioning Agent Wizard** al op de desktop. Zo niet, installeer deze dan vanuit de Entra Portal

Start deze op met de volgende settings:
- HR-driven provisioning
- Meld je aan met het **Entra Gobal Admin account** van de Tenant
- Geef vervolgens de **AD Domain Administrator** credentials op
- klik op **Confirm**

Ga nu naar de **Entra portal** en ga naar:
- **Entra ID > Entra Connect**
- Klik op **Cloud Sync** en ga kies dan voor **New Configuration > AD to Microsoft Entra ID**
- Selecteer de Agent en klik op **Create**
- Klik op de domeinnaam en pas het volgende aan:
              - Properties: Prevent accidental deletion - **Enabled**
              - Properties: Accidental deletion threshold - **500**
- Scoping filters: Vul de DN in van de OU waar de gehele organisatie onder valt. Dus niet de Root OU, maar de bovenste OU waaronder de users en devices van het AD vallen


## Cloud Kerberos Trust

In Hybride installaties, waarbij zowel een Active Directory als Entra ID in gebruik zijn, kan het nodig zijn om Kerberos Cloud Trust te activeren. Hiermee kunnen Entra-Joined werkplekken toch authenticeren op een lokale server die lid is van Active Directory. Om specifiek te zijn gaat het dan alleen om Entra-Joined werkplekken die met behulp van Windows Hello for Business inloggen.

Er zijn enkele voorwaarden voor deze oplossing:

- Alle gebruikers moeten in Active Directory aangemaakt zijn, en van daaruit Syncen naar Entra via Entra Cloud Sync of Connect
- Werkplekken moeten inloggen met behulp van Windows Hello for Business
- Werkplekken moeten "Line of sight" hebben met een Active Directory Server, en moeten de juiste DNS instellingen gebruiken

##### Cloud Kerberos Trust activeren op Domain Controller

Eerst moeten we de benodigde Powershell modules installeren:
```
# First, ensure TLS 1.2 for PowerShell gallery access.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Install the AzureADHybridAuthenticationManagement PowerShell module.
Install-Module -Name AzureADHybridAuthenticationManagement -AllowClobber
```

Vervolgens installeren we het virtuele Domain Controller object. Hiermee wordt feitelijk Kerberos Cloud Trust in 1 keer geactiveerd. Let goed op de credentials die je invult, en je moet ook verschillende keren authenticeren.

```
# Specify the on-premises Active Directory domain. A new Microsoft Entra ID
# Kerberos Server object will be created in this Active Directory domain.
$domain = $env:USERDNSDOMAIN

# Enter an Azure Active Directory Hybrid Identity Administrator username and password.
$cloudCred = Get-Credential -Message 'Enter the Global Admin credentials for this Tenant.'

# Enter a Domain Administrator username and password.
$domainCred = Get-Credential -Message 'Enter the Domain Admin (AD) credentials.'

# Create the new Microsoft Entra ID Kerberos Server object in Active Directory
# and then publish it to Azure Active Directory.
Set-AzureADKerberosServer -Domain $domain -CloudCredential $cloudCred -DomainCredential $domainCred
```

##### Intune policy maken om Hello for Business te gebruiken voor On-Prem authenticatie

- Configureer in Intune een nieuwe Configuration Policy met de naam **Supracom: Kerberos Cloud Trust**
- **Windows 10 en hoger** -> **Settings Catalog**
- Zoek in de instellingen naar **Use Cloud Trust for On Prem Auth** en schakel deze optie in
- Assign deze Policy aan de groepen **Devices-EntraJoined** en aan **Users-AllUsers**

<p class="callout warning">Je kunt de werking NIET testen met een Domain Admin account. Die werken niet in combinatie met Kerberos Cloud Trust. Gebruik dus altijd een normale gebruiker om te testen.</p>

De volledige uitleg is hier te vinden: [https://petervanderwoude.nl/post/configuring-windows-hello-for-business-cloud-kerberos-trust/](https://petervanderwoude.nl/post/configuring-windows-hello-for-business-cloud-kerberos-trust/)

##### Microsoft Entra Kerberos voor Azure Storage Accounts

Ik noteer hier even een link naar een Blog die alles uitlegt over Microsoft Entra Kerberos voor Azure Storage accounts. Dit naar aanleiding van een storing bij BTL waarbij het Storage Account geen actuele App Registratie meer had binnen Entra.

[https://www.thetechtrails.com/2025/11/azure-file-share-entra-kerberos-configuration-guide.html](https://www.thetechtrails.com/2025/11/azure-file-share-entra-kerberos-configuration-guide.html)


## [CONCEPT] Microsoft Entra Global Secure Access
Het is mogelijk om verkeer richting het Microsoft Azure platform te tunnelen door een virtuele verbinding, vergelijkbaar met VPN. Deze verbindingen worden ook wel SASE of ZTNA verbindingen genoemd. Daarnaast is het ook mogelijk om een agent te installeren op een lokale server, zodat ook deze verbonden wordt met het Azure platform en er ook mee verbonden kan worden vanaf clients die verbonden zijn met Azure. De verzamelnaam voor deze verbindingen is Global Secure Access.

Er zijn binnen Global Secure Access 3 profielen:
1. Microsoft Access - Alle traffic naar Microsoft 365 applicaties zoals Exchange Online, Sharepoint en Onedrive - Geen licentie vereist
2. Private Access - Alle traffic naar een agent/proxy die zich op een server in een lokaal netwerk bevindt - Aparte licentie vereist "Microsoft Entra Private Access"
3. Internet Access - Alle traffic naar het internet. Bedoelt om op clientniveau echt al het internetverkeer te beheren - Aparte licentie vereist "Microsoft Entra Internet Access"

##### Activeren Global Secure Access
- Koppel de juiste Entra Global Secure licenties aan de gebruikers
- Ga naar [https://entra.microsoft.com](https://entra.microsoft.com)
- Ga in het zijvenster naar **Global Secure acces** en activeer Global Secure Access

##### Installatie Global Secure Access Client
- Download de client software via **Global Secure Acces > Connect > Client download**, of ga naar [https://aka.ms/GSAClientDownload](https://aka.ms/GSAClientDownload).
We maken er nu een .intunewin bestand van om hem te kunnen deployen. 
- Download hiervoor de preptool IntuneWinAppUtil.exe
- Maak 2 mappen aan in je folder: **Input** en **Output**
- In de Input plaats je **globalsecureacces.exe**
- Start nu de Preptool en voer de source in output folder in. Je hebt nu een Intunewin bestand gemaakt die klaar is om gedeployed te worden.
- Ga nu naar intune.microsoft.com en ga naar Apps > Windows en maak een nieuwe Windows app (WIN32) app aan. Installeer hem met de volgende instellingen
```
Name: Global Secure Access
Publisher: Microsoft
Install Command: GlobalSecureAccessClient.exe /quiet /norestart
Uninstall Command: GlobalSecureAccessClient.exe /uninstall /quiet /norestart
Rules Format: Manually configure detection rules
Rule type: File
Path: C:\Program Files\
File or folder: Global Secure Access Client
```

- Bij Assignment selecteer je onder Required de groep: **Application-GSA_PrivateAccess** (en andere GSA groepen indien van toepassing)

##### Configuratie Private Access
- Maak 2 nieuwe Entra groepen aan: **License-GSA_PrivateAccess** en **Application-GSA_PrivateAccess**
- Ga naar Connect > Traffic forwarding en activeer hier Private acces profile. Zet User and group assignments op **Application-GlobalSecureAcces**

**Installatie Private Access Endpoint in lokaal netwerk**
- Ga naar Entra.microsoft.com > Global Secure Acces > Connectors and sensors >  Download connector service en
- installeer deze op een server in het lokale netwerk of in Azure
- Maak ook gelijk een Connector group aan en Koppel de connector de je net geinstalleerd hebt hier aan. Zorg altijd dat de server niet gekoppeld is aan de default group

**Instellen Routes**
Wanneer al het voorwerk gedaan is kunnen we een route aanmaken die ervoor zorgt dat de traffic gerouteerd word via de connector. 

- Ga naar **Global Secure Acces > Applications > Quick Access**.
- Geef hier de naam op: **Quick Access** en selecteer de juiste connector group.
- Klik onder **Application Segment** op **Add** 
  - Bij de FQDN voer je de volledige hostname in van de bestemming, samen met het poortnummer waarover het dataverkeer loopt
    - Voorbeeld SMB verkeerd op Azure Storage account: **viedentastorage001.file.core.windows.net**, TCP poort **445**
    - 
- Wanneer dit gedaan is en je hebt de configuratie gesaved refresh je de pagina. Ga hierna naar **Users and Groups** and voeg hier de **Application-GSA_PrivateAccess** groep toe

Nu zou het verkeer gerouteerd moeten worden via GSA. Test dit ook zeker via een workstation om te kijken of alles werkt. Het kan zijn dat het 15-20 minuten duurt voordat dit werkt. Heb dus geduld voordat je gaat troubleshooten