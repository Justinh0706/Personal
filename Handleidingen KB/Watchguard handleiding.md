## Voorwoord

Deze handleiding beschrijft de basisinstallatie van Watchguard routers, maar ook de configuratie van specifieke onderdelen zoals SSL VPN, Site-2-Site VPN en WAN failover.

We configureren Watchguard routers bij voorkeur via de System Manager software en niet via de Web Interface. Alle instructies in dit document zijn dus ook gebaseerd op "Watchguard System Manager".

## Basisinstallatie

Er zijn een aantal algemene zaken die je moet uitvoeren voordat je met de daadwerkelijke configuratie kunt beginnen.

### Voorwerk

Eerst moeten we de Watchguard activeren in ons portaal. Dit zorgt ervoor dat de feature key vrij komt en hier vernieuwen we de feature keys ook.

- Ga naar [Watchguard.com/activate](https://www.watchguard.com/activate)
- Vul het serienummer van de Watchguard in
- Wanneer er nog geen licentie aan gekoppeld zit, vul je deze apart in
- Kies een naam volgens de standaard [T145_praktijk_Naam], bijvoorbeeld T145_Tandartspraktijk_Haas
- Pas je eigen netwerkadapter aan zodat je de Watchguard kunt benaderen (het standaard IP adres van de Watchguard is `https://10.0.1.1:8080` bij een factory reset, en de LAN poort heeft dan nog geen DHCP). Gebruik bijvoorbeeld: IP Adres: 10.0.1.5, Subnetmasker: 255.255.255.0, Default Gateway: 10.0.1.1, DNS: 1.1.1.2
- Verbind met de webinterface van de Watchguard via `https://10.0.1.1:8080`
- Doorloop de Wizard en kies als eerste voor locally managed
- Vul de instellingen in naar de omgeving van de klant
- Laat de External port op DHCP staan zodat deze een IP adres krijgt vanuit onze DHCP (dit zorgt ervoor dat de Watchguard zijn Feature key kan ophalen)
- Bereid hierna de External port voor op de omgeving van de klant

#### Active Directory

In het geval van een AD omgeving gebruik je voor de DNS de AD server van de klant. Hier draait meestal hun DNS, weet je dit niet zeker kijk dit dan na. Gebruik voor de secondary DNS server bijvoorbeeld Cloudflare (1.1.1.2). Domain name hoef je ook enkel in te vullen wanneer de klant een lokale active directory server heeft.

#### Entra ID

In het geval van een Entra omgeving stel je de DNS in op bijvoorbeeld Cloudflare (1.1.1.2) en als secondary bijvoorbeeld Google (8.8.8.8). Domain name hoef je hier niet in te vullen.

- Kies als "Status passphrase" een Horse-Battery-Stable wachtwoord
- Kies als "Read/Write" of "Admin" passphrase een Horse-Battery-Stable wachtwoord

### Eerste configuratie via System Manager

- Verbind met Watchguard System Manager via het IP dat je tijdens de first run wizard hebt ingevuld (meestal 192.168.10.1)
- Maak onder **Setup → Aliases** een alias aan met de naam **Supracom**:
  - Host IPv4 Adres: 217.67.236.37 (nieuwe glasvezel)
  - Network IPv4 Adres: 95.97.82.8 /29 (Ziggo)
- Maak onder **Setup → Aliases** een alias aan met de naam **Whitelist-Ping**:
  - FQDN: sys-wl-ping.supracom.nl
- Schakel **Block Failed Logins** in met de standaard opties: **Setup → Authentication → Authentication Settings → Block Failed Logins**
- Schakel **Account Lockout** in met de standaard opties: **Setup → Authentication → Authentication Settings → Account Lockout**
- Registreer de Firebox in Hudu met:
  - Naam: RTR-01 (of ander volgnummer indien van toepassing)
  - Serienummer
  - Aanschafdatum
  - Verloopdatum van de Livesecurity support

### Standaard aangemaakte Proxy's verwijderen

Nieuwere Watchguard routers zijn standaard voorzien van enkele Proxy's zodat je daarmee direct aan de slag kan voor specifieke filtering. Dit is alleen van toepassing indien de Watchguard beschikt over de volledige Security Suite, wat bij onze klanten meestal niet het geval is. Daarom moeten de volgende Proxy regels verwijderd worden om vage problemen met internet te voorkomen:

- Verwijder de HTTP-Proxy
- Verwijder de HTTPS-Proxy
- Verwijder de FTP-Proxy
- Verwijder de DNS-Proxy

Het resultaat van deze actie is dat het uitgaande HTTP/HTTPS- en FTP-verkeer terugvalt op de standaard "Outgoing" regel, die al het uitgaande verkeer richting internet standaard toestaat.

## Watchguard Cloud Management

We beheren de Watchguard routers van onze klanten (ook zonder serviceovereenkomst) via de Watchguard Cloud. Vooralsnog doen we dit alleen om de firmware centraal te kunnen updaten. In de toekomst zullen we ook policy's centraal uitrollen via dit systeem. Doe dit bij voorkeur vroeg in het traject, zodat de firmware up-to-date is voordat je met de gedetailleerde configuratie verder gaat.

- Log in op [cloud.watchguard.com](https://cloud.watchguard.com)
- Log in via SSO met IDP name **SupracomBV**
- Maak de klant aan met exact dezelfde naam als in HaloPSA, indien deze nog niet bestaat
- Klik in de linker kolom op **Overview**
- Ga via **Inventory** naar **Unallocated**
- Klik je toegevoegde Firebox aan en koppel deze aan de klant
- Klik in de linker kolom op de klantnaam
- Ga naar **Configure → Devices** om het device toe te voegen
- Kies bij **Device Management** voor **Local Management** (anders wordt je lokale configuratie gewist)
- Update de firmware indien deze niet up-to-date is (> v12.0); is de firmware wel up-to-date, dan hoef je verder niets te doen met verificatie en doe je de rest vanaf de Firebox

## Configuratie

### Instellen interfaces

- Zorg dat het IP adres van de trusted poort klopt
- Stel de DHCP in op de trusted poort zodat dit overeenkomt met de omgeving
- Stel bij een AD omgeving een DHCP relay in op het IP adres van de server, zodat de DHCP wordt uitgedeeld door de server
- Maak bij een Entra ID omgeving een DHCP pool aan van 192.168.10.100-192.168.10.200, zodat de Watchguard zelf de DHCP uitdeelt
- Inventariseer wat voor verbinding de klant heeft op de external poort
- Laat de external poort op DHCP staan bij een VDSL- of DSL-verbinding
- Stel bij een FTTH-verbinding een VLAN in via Network configuration → VLAN
- Maak een VLAN aan met een gepaste naam
- Zet de security zone van het VLAN op External
- Vul de VLAN ID in naar behoren
- Vink Use DHCP Client aan
- Druk onder de External poort op configure
- Zet de interface type op VLAN
- Selecteer de VLAN die je zojuist hebt aangemaakt

#### Instellen van een 5G Failover

- Kies een optional poort voor de 5G failover verbinding
- Configureer deze poort als volgt:
  - Name: 5G Failover
  - Interface Type: External
  - Use DHCP Client
- Ga naar Multi-WAN configuration en laat deze op Failover staan
- Zet onder Configure de hoofdverbinding bovenaan en de 5G verbinding daaronder (anders gebruikt de Watchguard de 5G verbinding als primaire verbinding)
- Zet Failback for Active Connections op Gradual failback: Allow connections to use failover interface
- Voeg onder monitored interfaces de primaire verbinding toe voor de link monitor (kies hier nooit de 5G verbinding)
- Vul onder settings de DNS server in waarnaar de link monitor moet pingen (bijvoorbeeld 1.1.1.2), zodat de Watchguard kan detecteren of de verbinding nog online is en kan overschakelen naar de failover verbinding wanneer de ping stopt

### Watchguard als DHCP & DNS server + Conditional DNS forwarding (enkel bij Entra ID/Entra Connect omgevingen)

Bij netwerken die volledig Cloud gaan zonder Active Directory, of bij hybride netwerken met een Active Directory Domain Controller in een externe omgeving, is het nodig om de Watchguard als DNS server in te schakelen voor de lokale clients. De Watchguard zal dan in de meeste gevallen ook de DHCP server worden voor het LAN.

Pas de volgende configuratie toe om de Watchguard als DNS en DHCP server in te schakelen:

- Stel onder **Network → Configuration → DNS** de Domain Name in op de publieke domeinnaam van de klant, bijvoorbeeld "barneveldsttl.nl"
- Stel de DNS Servers in op 1.1.1.2 + 9.9.9.9
- Zet Enable DNS Forwarding op Enabled
- Kies voor Listen on all Trusted, Optional and Custom interfaces

**Alleen bij Hybrid Entra/AD — bijv. met AVD:**

- Stel onder Conditional DNS Forwarding de Domain in op het FQDN van het Active Directory domein, bijvoorbeeld "ad.barneveldsttl.nl"
- Stel de DNS server in op het IP adres van de Active Directory server
- Schakel op de LAN interface de DHCP server in
- Stel de DNS Server in op het IP adres van de Watchguard zelf (meestal 192.168.10.1)
- Gebruik de standaard DHCP Pool (meestal "192.168.10.100 - 192.168.10.254")

Meer informatie over DNS forwarding: [DNS forwarding — WatchGuard Help Center](https://www.watchguard.com/help/docs/help-center/en-US/content/en-US/Fireware/networksetup/dns_forwarding_about.html)

### Port-forwarding (NAT)

Stel nu, indien van toepassing, alle relevante port-forwarding regels in voor het netwerk. Je kunt daarbij kiezen voor voorgeconfigureerde regels (packet-filters) of eigen regels (custom).

Bij Watchguard wordt onderscheid gemaakt tussen Policies en Proxies. Een Policy is een standaard firewall + NAT regel, en een Proxy is een firewall-regel waaraan je veel meer instellingen kunt verbinden. Denk daarbij aan antivirus- en spamfiltering, deep-packet-inspection enzovoort. Voor proxy regels zijn vaak ook aparte licenties vereist.

- Houd de proxy regel aan indien de eindklant gebruik gaat maken van die dienst (zoals aangegeven in de opdracht)
- Vervang de proxy regels door packet filter regels indien dit niet het geval is
- Controleer of je een back-up van een eventuele bestaande Watchguard kan terugzetten
- Wees terughoudend met het terugzetten van een back-up als je twijfelt over de bestaande instellingen
- Maak een inventarisatie van de huidige configuratie van de router, zodat je hieruit de firewall regels kunt aanmaken voor bijvoorbeeld thuiswerken

#### Lokale AD

Voor een lokale AD omgeving vul je in ieder geval het volgende in:

- Klik met je rechtermuisknop op de policy manager
- Klik op add policy en Manage custom
- Maak een policy aan voor HP iLO met Name: HP iLO, Protocols: TCP - 8000, TCP - 4430, TCP - 17990, TCP - 17988
- Klik op new om de policy aan te maken
- Dubbelklik op deze policy om hem toe te voegen
- Vul onderin onder from de waarden Any-Trusted, Any-Optional, Supracom in
- Maak onder to een SNAT aan met de naam HP iLO en het IP adres waar HP iLO op draait (meestal 192.168.10.15 volgens blauwdruk), zodat het verkeer enkel gerouteerd wordt naar dit specifieke IP adres
- Sla de policy op
- Maak een policy aan voor RDP naar de SRV-01 (dit is binnen Watchguard al een bestaande policy)
- Druk op add policy en zoek onder packet filters naar RDP
- Vul bij From de waarden Any-Trusted, Any-Optional, Supracom in
- Voeg onder To een SNAT toe met het IP adres van de SRV-01
- Sla de policy op
- Dubbelklik op de ping policy
- Voeg de alias whitelist-ping toe aan de ping policy, zodat de ping van PRTG wordt doorgelaten
- Sla de policy op

#### Entra ID

Voor Entra heb je in de blauwdruk geen port forwardings nodig in de firewall. Kijk dit wel goed na, ze kunnen bijvoorbeeld nog camera's hebben of andere apparatuur die dit nodig kan hebben.

- Dubbelklik op de ping policy
- Voeg de alias whitelist-ping toe aan de ping policy, zodat de ping van PRTG wordt doorgelaten
- Sla de policy op

#### Watchguard Cloud
- Schakel **Enable Watchguard Cloud** in onder het menu **Setup → Watchguard Cloud → Enable Watchguard Cloud**. Blijf in het portal van Watchguard cloud refreshen tot deze online komt.

## SSL VPN

### SSL VPN met DUO MFA via RADIUS

Het is mogelijk om VPN verbindingen naar een Watchguard firewall te beveiligen met MFA. Hier is wel een lokale Active Directory omgeving voor nodig, omdat dit via RADIUS loopt.

- Volg het volgende Watchguard artikel: [DUO Security Authentication — Integration Guide](https://www.watchguard.com/help/docs/help-center/en-US/Content/Integration-Guides/General/duo-security-authentication.html)
- Voeg de RADIUS Authenticator Server toe binnen de Watchguard
- Zorg dat het vinkje bij "Require the Message-Authenticator Attribute" UIT staat

### SSL VPN met Entra MFA

##### Voorwaarden

- Lokale AD server met Entra Cloud Sync (niet te verwarren met Entra/Azure AD Connect)
- NPS server geïnstalleerd met MFA PS extension
- AD security group **SSLVPN-Users**
- Tenant minimaal Entra P1 capable
- RADIUS poorten open in firewall server
- De gebruiker logt in met de volledige UPN (gebruikersnaam@domeinnaampraktijk.nl)

##### Installatie NPS en RADIUS server

- Installeer de Network Policy and Access Service rol via de Server Manager
- Configureer een Radius Client met Friendly name: Watchguard
- Vul als Address het IP van de Watchguard in, bijvoorbeeld 192.168.10.1
- Genereer een Shared secret en sla deze op in Hudu
- Doorloop de wizard voor een nieuwe Network Policy
- Vul als Policy name "Watchguard" in
- Stel als Condition de User group in (bijvoorbeeld AD\SSLVPN-Users)
- Kies Access granted
- Vink bij EAP Types PAP aan (voor SSLVPN is dit voldoende, rest default laten)
- Laat Constraints op default staan
- Stel onder Settings Standard add in (Filter-Id = SSLVPN-Users)

##### Installatie Watchguard

- Voeg op de Watchguard onder Authentication servers een RADIUS server toe
- Vul als IP Address het IP van de NPS server in
- Vul als Port 1812 in
- Vul als Shared Secret de shared secret in die in Hudu staat (gemaakt op de NPS)
- Controleer of je met een AD gebruiker kunt inloggen op de VPN (let op: log in met een UPN)
- Installeer de MFA extensie op de NPS service nadat het inloggen gelukt is: [Download NPS Extension for Azure MFA — Microsoft Download Center](https://www.microsoft.com/en-us/download/details.aspx?id=54688)

Nadat de MFA extensie is geïnstalleerd is dit deel troubleshooten lastig.

##### Configuratie MFA extensie

Na de installatie van de plug-in moet deze geconfigureerd worden. Dit kan met behulp van PowerShell en het bijbehorende script:

```
cd "C:\Program Files\Microsoft\AzureMfa\Config"
.\AzureMfaNpsExtnConfigSetup.ps1
```

- Log in met de Global Admin wanneer de prompt hierom vraagt
- Voer tijdens de installatie ook de Tenant-ID in
- Controleer aan het eind van het script of de uitvoering succesvol is weergegeven
- Open het register en browse naar:

  ```
  Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\AzureMfa
  ```

- Voeg de volgende String Value toe:

  ```
  OVERRIDE_NUMBER_MATCHING_WITH_OTP (Value data: FALSE)
  ```

  (dit is nodig omdat de RADIUS server niet overweg kan met TOTP en anders elke validatie zou falen; in plaats daarvan stellen we een push bericht in via de MS Authenticator, vergelijkbaar met DUO)

##### Testen

- Log in met een gebruiker die de juiste Entra P1 licentie heeft en MFA in de MS Authenticator app heeft geregistreerd
- Bevestig het push bericht in de app (de connectie komt na akkoord tot stand; dit kan circa 10 seconden duren)

##### Troubleshooting

Onderzoeken waarom een gebruiker niet in kan loggen kan lastig zijn, omdat een deel van de verificatie in Entra plaatsvindt. Er zijn een paar trucjes die het makkelijker maken:

- Maak een back-up van de twee sleutels in het volgende registerpad, om de MFA plugin tijdelijk uit te schakelen:

  ```
  Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AuthSrv\Parameters
  ```

- Verwijder vervolgens deze sleutels
- Herstart de NPS service
- Bekijk de Windows logboeken voor een duidelijkere aanwijzing waarom een gebruiker niet kan inloggen (te vinden onder **Event Viewer → Custom Views → Server Roles → Network Policy and Access Services**)
- Zet de registersleutel terug
- Herstart de NPS service opnieuw om de push weer te testen
- Controleer in **Applications and Services Logs → Microsoft → AzureMfa → AuthZ → AuthZOptCh** of een gebruiker juist heeft gereageerd

Er is een video die veel voorkomende fouten/oplossingen laat zien: [Basic NPS and MFA extension troubleshooting — YouTube](https://www.youtube.com/watch?v=EHvqMEjorJk&t=594s)

##### Bronnen

- [Use Microsoft Entra multifactor authentication with NPS — Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-mfa-nps-extension)
- [Azure MFA with NPS extension — WatchGuard Community](https://community.watchguard.com/watchguard-community/discussion/3829/azure-mfa-with-nps-extension)
- [Configure Windows Server to authenticate mobile VPN users with RADIUS and Active Directory — WatchGuard](https://techsearch.watchguard.com/KB/WGKnowledgeBase?lang=en_US&SFDCID=kA22A000000XZlhSAG&type=KBArticle)

### In- of uitschakelen webinterface SSL VPN

Om de diverse aanmeldpogingen te limiteren welke gegenereerd worden door onze vrienden uit twijfelachtige landen, kunnen we de webinterface van de SSLVPN pagina in- of uitschakelen. Vanaf versie 12.11 is dit helemaal niet meer beschikbaar; dit is verwijderd in de firmware.

> **Let op:** dit is niet meer nodig als je de nieuwste firmware hebt en de functie Block Failed Logins aan hebt staan.

- Maak vanuit LAN een SSH verbinding naar de Watchguard (dit kan zonder extra tools, mits up-to-date Windows Server, vanuit je Windows CLI):

  ```
  ssh admin@192.168.10.1 -p 4118
  ```

- Gebruik de volgende commando's om de webinterface uit te schakelen:

  ```
  WG# config
  WG(config)# policy
  WG(config/policy)# no sslvpn web-download enable
  ```

- Gebruik de volgende commando's om de webinterface weer in te schakelen:

  ```
  WG# config
  WG(config)# policy
  WG(config/policy)# sslvpn web-download enable
  ```

## PRTG Monitoring

Je bent bezig met de installatie van een router die verbonden zal worden met het internet. Vanwege onze dienstverlening is het noodzakelijk om de internetverbinding(en), indien nog niet gebeurd, op te nemen in de monitoring.

- Volg het artikel [WAN monitoring met PRTG](https://bookstack.supracom.stellarhosted.com/books/monitoring/page/wan-monitoring-met-prtg)

## Oude Firebox verwijderen

Wanneer een Firebox vervangen wordt, moet de oude verwijderd worden uit het productoverzicht:

- Verwijder de Firebox uit de Watchguard Cloud
- Ga naar [myproducts.watchguard.com/manage-products](https://myproducts.watchguard.com/manage-products)
- Zoek het device op
- Klik op **Retire**