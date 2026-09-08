## Sharepoint
We maken standaard 2 Sharepoint sites aan: **Algemeen** en **Management**. Deze Sites zijn automatisch aangemaakt bij het aanmaken van de Microsoft 365 groepen in Microsoft Entra. In dit deel van de handleiding stellen we nog een paar specifieke zaken in.


## Sharepoint sites synchroniseren
Binnen Intune hebben we een policy ingesteld om beide Sharepoint Sites te synchroniseren in de Onedrive client op de werkplekken. Het is normaal dat je deze Sharepoint sites niet meteen ziet, omdat Microsoft 8 uur marge aanhoudt om automatische synchronisaties uit te rollen. Dat is met een TimerAutoMount registerinstelling te versnellen, maar ook dat is niet waterdicht. Mocht je de Sharepoint site toch direct willen zien in Onedrive, dan kun je de Sync knop handmatig aanklikken binnen een Sharepoint site op de werkplek.


## Rechten controleren
De Management site is alleen toegankelijk voor leden van die Microsoft 365 groep. We controleren nu of die Sharepoint site de juiste rechten heeft.

- Ga naar het Sharepoint Admin Center [https://admin.microsoft.com/sharepoint](https://admin.microsoft.com/sharepoint)
- Ga naar **Sites -> Active Sites** en open de site **Management**
- Controleer onder **Membership** of bij **Site Members** alleen de leden van de groep **Management - Members** staat
- Controleer onder **Settings** of de privacy van de site ingesteld staat als **Private**

Herhaal bovenstaande stappen voor de site **Algemeen** en eventueel andere sites die je aangemaakt hebt op aanvraag.



## Sharing
We stellen Sharepoint in om bestanden niet standaard te kunnen delen met externe of anonieme ontvangers.

- Ga naar het Sharepoint Admin Center [https://admin.microsoft.com/sharepoint](https://admin.microsoft.com/sharepoint)
- Onder het kopje **External Sharing** (Content can be shared with)  moet zowel **SharePoint** als **OneDrive** de optie krijgen van **Least permissive**