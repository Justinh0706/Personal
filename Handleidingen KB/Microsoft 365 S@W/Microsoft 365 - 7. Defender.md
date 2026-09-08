Deze handleiding is onderdeel van een serie van handleidingen die betrekking hebben op het inrichten van een Microsoft 365 Business Premium omgeving. Je wordt in deze handleidingen naar diverse portalen binnen de Microsoft 365 Cloud verwezen voor beheertaken.

## Basis informatie
Defender staat natuurlijk altijd al geïnstalleerd binnen Windows. Met een Business Premium omgeving kun je deze installatie ook managen vanuit de Cloud, en je kunt de logging vanuit Defender koppelen aan de Cloud zodat dit centraal inzichtelijk wordt.

Dit Blog artikel legt de basics uit van Defender in combinatie met Microsoft 365 Business Premium: [https://conditionalaccess.uk/how-to-deploy-defender-for-endpoint-windows/](https://conditionalaccess.uk/how-to-deploy-defender-for-endpoint-windows/)

En dit is een nuttige video om te handmatige installatie stappen te zien:
[https://www.youtube.com/watch?v=TkaIJexEHHk](https://www.youtube.com/watch?v=TkaIJexEHHk)


## Zaken om te configureren

##### Onboarden van Defender bij Security Portal
- Security portal eenmalig opstarten
- Ga eventueel naar **Endpoints - Configuration Management - Device Configuration**
- Dit triggert een first-run wizard in een Tenant waar Defender nieuw is toegevoegd met een BP licentie. Na een paar uur opnieuw terugkomen en Getting Started uitvoeren voor automatisch onboarden
- Als Getting Started niet verschijnt, dan naar **Intune -> Endpoint Security -> Endpoint Detection and response -> EDR Onboarding status -> Deploy preconfigured policy**
<br>
<br>
[![](https://bookstack.supracom.stellarhosted.com/uploads/images/gallery/2025-03/scaled-1680-/ifjQpCJd2WMuQ0s2-image-1743427930059.png)](https://bookstack.supracom.stellarhosted.com/uploads/images/gallery/2025-03/ifjQpCJd2WMuQ0s2-image-1743427930059.png)


##### Huntress integratie instellen
- Ga naar **Huntress -> {Kies organisatie} -> Home -> Microsoft Defender for Endpoint -> Setup Integration**
- Autoriseer de Huntress integratie met de Global Admin van de tenant (De eerste keer krijg je mogelijk een foutmelding. Doet het vervolgens nog een keer en het werkt wel.)


## Security instellingen

##### Standard Protection

We willen graag dat de klant tenant een set standaard beveiligingsopties actief heeft, die door Microsoft beheerd worden. Hiervoor gaan we het 'Standard Protection' policy van Microsoft activeren. 

 - Log in bij [https://security.microsoft.com](https://security.microsoft.com)
 - **Email & Collaboration  --> Policies & rules**
 - **Threat policies --> Preset security policies --> Standard protection**
 - Doorloop de wizard wanneer je klikt op **Manage protection settings**
	 - **Apply Exchange Online Protection**: Apply to all recipients
	 - **Apply Defender for Office 365 protection**: Apply to all recipients
	 - **Impersonation Protection**: Instellen naar eigen inzicht, maar hou het beperkt als je nog niet goed weet wat dit doet
	 - **Policy Mode**: Turn on the policy