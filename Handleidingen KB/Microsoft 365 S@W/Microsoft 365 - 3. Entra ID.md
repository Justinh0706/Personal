## Voorwaarden
Voordat je met dit hoofdstuk begint, dient eerst deel 1 van de Microsoft 365 handleiding uitgevoerd te zijn.

## Aanmaken accounts
Maak alle gebruikersaccounts aan. Shared (generieke) accounts beveiligen we met een complex "Horse-Battery-Staple" wachtwoord, die we via Windows Hello for Business voorzien van een pincode op de werkplekken. 

- Leg een werkplek wachtwoord vast in Hudu
- Leg ook een aparte werkplek pincode vast in Hudu


<p class="callout info">Het werken met pincode authenticatie via Windows Hello for Business is veiliger, en gebruiksvriendelijker. Deze aanmeldmethode wordt ook gezien als Phishing Resistant MFA, waardoor we gedeelde werkplekken niet hoeven uit te sluiten van MFA Conditional Access Policy's</p>

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
