## Voorwaarden
Voordat je met dit hoofdstuk begint, dient eerst deel 1 van de Microsoft 365 handleiding uitgevoerd te zijn.

## Aanmaken accounts
Maak alle gebruikersaccounts aan. Shared (generieke) accounts beveiligen we met een complex "Horse-Battery-Staple" wachtwoord, die we via Windows Hello for Business voorzien van een pincode op de werkplekken. 

- Leg een werkplek wachtwoord vast in Hudu
- Leg ook een aparte werkplek pincode vast in Hudu


<p class="callout info">Het werken met pincode authenticatie via Windows Hello for Business is veiliger en gebruiksvriendelijker. Deze aanmeldmethode wordt ook gezien als Phishing Resistant MFA, waardoor we gedeelde werkplekken niet hoeven uit te sluiten van MFA Conditional Access Policy's</p>

<p class="callout warning">Indien er sprake is van Entra Cloud Sync vanuit een lokale Active Directory, dan maak je de gebruikers en Assigned groepen niet aan in Entra, maar via AD. Onderstaand script is in dat geval ook NIET te gebruiken.</p>

##### Gedeelde gebruikersaccounts

**Powershell script voor aanmaken gebruikers (Alleen Entra)**

Download het script in onze Github. Gebruik hiervoor de Supracom-Script-downloader. Ook kan je hem online downloaden in onze Github. Mocht je nog geen toegang hebben tot onze repository vraag dit dan even aan Matthijs of Justin.

https://github.com/Supracom/Supracom/blob/master/Microsoft%20Entra/Entra%20Users%20and%20Groups.ps1

##### Persoonlijke accounts
Maak nu ook alle persoonlijke accounts aan. Dit zijn meestal accounts voor een tandarts/eigenaar en de praktijkmanager. Deze accounts krijgen hun eigen persoonlijke wachtwoord.

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

### Gebruikers toevoegen aan de lokale Administrators groep
Soms is het nodig om een gebruiker lid te maken van de lokale Administrator groep. Met een Entra Joined werkplek kun je dit doen middels het volgende commando. Vervang "Rontgen1" met de juiste gebruikersnaam (AzureAD is wel altijd hetzelfde)

```
net localgroup administrators AzureAD\Rontgen1 /add
```
## Conditional Acces
Conditional Access is een fundamenteel onderdeel van een goed beveiligde Azure omgeving.
Belangrijk om te weten over CA policies is dat je voor elk scenario een policy moet hebben. Exclude je bijvoorbeeld een groep gebruikers uit de eerste policy, dan moet je nog een andere policy hebben die deze groep expliciet wél behandelt. Vereis je MFA in een policy én moet het device compliant zijn, dan moet er ook een policy zijn die dit vereist voor non-compliant devices. Als er geen match is voor een gebruiker/groep/locatie, dan heeft dat account vrij toegang tot Azure zonder MFA of andere extra beveiliging.<br></br>

We maken een standaard CA policy aan die alle verbindingen beveiligt met MFA, behalve die vanuit vertrouwde locaties. Ook sluiten we bepaalde accounts uit die gebruikt worden voor Directory Synchronization, of die op een andere manier beveiligd worden met MFA.

Voor het deployen van de conditional access gebruiken we Inforcer en de baseline die we assigned hebben. Dit pakken we verder op in hoofdstuk 4 van Intune.

### Named Locations
We beginnen met het instellen van de Named Locations. Standaard stellen we deze in op de locatie van de klant en het kantoor van Supracom.

- Ga naar de **Entra** portal via [https://entra.microsoft.com](https://entra.microsoft.com)
- Kies voor **Protection --> Conditional Access**
- Voeg een **Named Location** toe op basis van een IP-Adres
  - **Name:** Straatnaam van de klant
  - **IPv4:** IP-Adres van de klant (/32)
  - **Mark as trusted location:** Enable

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