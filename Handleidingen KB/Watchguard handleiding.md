## Voorwoord:

Deze handleiding beschrijft de basisinstallatie van Watchguard routers, maar ook de configuratie van specifieke onderdelen zoals SSL VPN, Site-2-Site VPN en WAN failover.

We configureren Watchguard routers bij voorkeur via de System Manager software en niet via de Web Interface. Alle instructies in dit document zijn dus ook gebaseerd op “Watchguard System Manager”

## Basisinstallatie
Er zijn een aantal algemene zaken die je moet uitvoeren voordat je met de daadwerkelijke configuratie kunt beginnen.

### Voorwerk
Eerst moeten we de Watchguard activeren in ons portaal. Dit zorgt ervoor dat de feature key vrij komt en hier vernieuwen we de feature keys ook. Ga naar Watchguard.com/activate, vul hier het serienummer in van de Watchguard. Wanneer er nog geen licentie aan gekoppeld zit moet je deze nog apart invullen. Kies hierna voor een naam. Normaal gesproken is het als volgt [T145_praktijk_Naam] Voorbeeld: T145_Tandartspraktijk_Haas.

- Log nu in op de webinterface van de Watchguard. Het standaard ip adres van de Watchguard is 10.0.1.1 bij een factory reset. De LAN poort heeft dan eerst nog geen DHCP. Je zult dus je eigen netwerkadapter in dit subnet moeten zetten om de Watchguard te benaderen. Pas dit dan dus aan naar bijvoorbeeld: IP Adres: 10.0.1.5, Subnetmasker 255.255.255.0, Default Gateway: 10.0.1.1, DNS: 1.1.1.1
Hierna zou je de watchguard moeten kunnen bereiken.
- Verbindt nu met de webinterface van de Watchguard middels de link: https://10.0.1.1:8080
- Doorloop nu de Wizard. Kies als eerste voor locally managed. Hierna vul je de instellingen in naar de omgeving van de klant. Aanrader is wel als je de Watchguard intern voorbereid om de External port op DHCP te laten staan zodat deze een IP adres krijgt vanuit onze DHCP. Dit zorgt ervoor dat hij zijn Feature key uiteindelijk kan ophalen. Wanneer dit allemaal gedaan is kunnen we de External port alvast voorbereiden voor de klant zijn omgeving.
#### Local AD 
In het geval van een AD omgeving gebruik je voor de DNS de AD server van de klant. Hier draait meestal hun DNS, weet je dit niet zeker kijk dit dan na. Gebruik voor de secondary DNS server bijvoorbeeld cloudfare (1.1.1.1). Domain name hoef je ook enkel in te vullen wanneer de klant een lokale active directory server heeft.

#### Entra ID
In het geval van een entra omgeving stel je de DNS in op bijvoorbeeld cloudflare (1.1.1.1) en als secondary bijvoorbeeld google (8.8.8.8). Domain name hoef je hier niet in te vullen.

- Kies als “Status passphrase” een Horse-Battery-Stable wachtwoord.
- Kies als “Read/Write” of “Admin” passphrase een Horse-Battery-Stable wachtwoord

- Verbind nu met Watchguard systemmanager met het ip dat je ingevuld hebt tijdens de first run wizard. Dit zou in meeste gevallen 192.168.10.1 moeten zijn.
- Maak nu de volgende Aliassen aan onder **Setup->Aliases**
  #### Supracom
  - Host IPV4 Adres: 217.67.236.37 Nieuwe glasvezel
  - Network IPV4 Adres: 95.97.82.8 /29 Ziggo
  #### Whitelist-Ping
  - FQDN: sys-wl-ping.supracom.nl

- Schakel **Block Failed Logins** in met de standaard opties: **Setup->Authentication->Authentication Settings->Block Failed Logins**
- Schakel **Account Lockout** in met de standaard opties: **Setup->Authentication->Authentication Settings->Account Lockout**
- Schakel **Enable Watchguard Cloud** in onder het menu **Setup -> Watchguard Cloud -> Enable Watchguard Cloud**
- Registreer de firebox in IT Glue:
    * Naam: RTR-01 (of ander volgnummer indien van toepassing) 
    * Serienummer
    * Aanschafdatum
    * Verloopdatum van de Livesecurity support

    
#### Standaard aangemaakte Proxy's verwijderen

Nieuwere Watchguard routers zijn standaard voorzien van enkele Proxy's zodat je daarmee direct aan de slag kan voor specifieke filtering. Dit is alleen van toepassing indien de Watchguard beschikt over de volledige Security Suite, wat bij onze klanten meestal niet het geval is. Daarom moeten de volgende Proxy regels verwijderd worden om soms vage problemen met internet te voorkomen:

- HTTP-Proxy
- HTTPS-Proxy
- FTP-Proxy
- DNS-Proxy

Het resultaat van deze actie is dat het uitgaande HTTP/HTTPS en FTP verkeer terugvalt op de standaard "Outgoing" regel, dat al het uitgaande verkeer richting internet standaard toestaat.

## Configuratie

### Port-forwarding (NAT)

Stel nu, indien van toepassing, alle relevante port-forwarding regels in voor het netwerk. Je kunt daarbij kiezen voor voorgeconfigureerde regels (packet-filters) of eigen regels (custom)

Bij Watchguard wordt onderscheid gemaakt tussen Policies en Proxies. Een Policy is een standaard firewall + NAT regel, en een Proxy is een firewall-regel waaraan je veel meer instellingen kunt verbinden. Denk daarbij aan antivirus- en spamfiltering, Deep-packet-inspection enzovoort. Voor proxy regels zijn vaak ook aparte licenties vereist. Indien er in de opdracht is aangegeven dat de eindklant gebruik gaat maken van één van deze diensten dan kun je de desbetreffende proxy aanhouden. Indien dit niet het geval is dan dien je de proxy regels te vervangen voor packet filter regels.

- Mocht de klant al over een Watchguard beschikken kijk dan of je misschien een back-up terug kan zetten van deze Watchguard. Mochten hier nog instellingen in staan waar je bij twijfelt is dit af te raden. Zorg in ieder geval dat je een inventarisatie maakt van de huidige configuratie van de router. Dan kun je hieruit de firewall regels aanmaken voor bijvoorbeeld thuis werken.

#### Lokale AD
Voor een lokale AD omgeving vul je in ieder geval het volgende in:

- Klik met je rechtermuis knop op de policy manager. Klik dan op add policy en Manage custom. We maken hier in ieder geval 1 policy aan en dat is voor HP iLo. Klik op new en voer het volgende in: Name: HP iLo, Protocols: TCP - 8000, TCP - 4430, TCP - 17990, TCP - 17988.
Dubbel klik nu op deze policy om hem toe te voegen. Nu gaan we instellen wie de poorten mag gebruiken die je net hebt ingevuld en stellen we ook in waar dit naartoe mag. 
Vul onder in onder from: Any-trusted, Any-optional, Supracom.
Onder to maak je een SNAT aan. Een SNAT zorgt ervoor dat het enkel gerouteerd word naar een specifiek IP adres. Maak nu een SNAT aan met de naam HP iLo en het IP Adres waar HP iLo op draait (Meestal 192.168.10.15 volgens blauwdruk). Sla nu deze policy op
- Maak hierna ook nog een policy een RDP naar de SRV-01. Dit is binnen Watchguard al een bestaande policy. Druk dus nogmaals op add policy, onder packet filters zou je dan RDP moeten vinden. Voeg deze toe met de volgende instellingen
From: Any-Trusted, Any-Optional, Supracom
To: Voeg hier weer een SNAT toe met het IP adres van de SRV-01
Sla deze policy weer op.

- Nu passen we een bestaande policy aan om de Ping door te laten van PRTG. Dubbelklik op de ping policy en voeg de alias whitelist-ping toe. Sla dit op.
#### Entra ID
Voor Entra heb je in de blauwdruk geen port forwardings nodig in de firewall. Kijk dit wel goed na, ze kunnen bijvoorbeeld nog camera's hebben of andere apparatuur die dit nodig kan hebben.
Wel moet je de ping doorlaten nog voor PRTG. Pas de bestaande policy Ping aan. Dubbelklik op de ping policy en voeg de alias whitelist-ping toe. Sla dit op.
### Watchguard als DHCP & DNS server + Conditional DNS forwarding (Enkel bij Entra ID/Entra Connect omgevingen)

Bij netwerken die volledig Cloud gaan zonder Active Directory, of bij Hybride netwerken met een Active Directory Domain Controller in een externe omgeving, is het nodig om de Watchguard als DNS server in te schakelen voor de lokale clients. De Watchguard zal dan in de meeste gevallen ook de DHCP server worden voor het LAN.

Pas de volgende configuratie toe om de Watchguard als DNS en DHCP server in te schakelen:

- Stel onder **Network -> Configuration -> DNS** de volgende zaken in:
  - **Domain Name**: Publieke domeinnaam van de klant, bijvoorbeeld "barneveldsttl.nl"
  - **DNS Servers**: **1.1.1.2 + 9.9.9.9**
  - **Enable DNS Forwarding**: **Enabled** en kies voor **Listen on all Trusted, Optional and Custom interfaces**


 **Alleen bij Hybrid Entra/AD - bijv met AVD:**
 
   **- Conditional DNS Forwarding:**
   - **Domain**: {FQDN van het Active Directory domein}, bijvoorbeeld "ad.barneveldsttl.nl"
 - **DNS server**: {IP adres van Active Directory server}
  - **Schakel op de LAN interface de DHCP server in**
  - **DNS Server**: IP adres van de Watchguard zelf (meestal 192.168.10.1)
  - **DHCP Pool**: Standaard DHCP Pool (meestal "192.168.10.100 - 192.168.10.254")

Meer informatie over DNS forwarding: [https://www.watchguard.com/help/docs/help-center/en-US/content/en-US/Fireware/networksetup/dns_forwarding_about.html](https://www.watchguard.com/help/docs/help-center/en-US/content/en-US/Fireware/networksetup/dns_forwarding_about.html)

### Instellen Interfaces
- De trusted poort hoef je niet veel aan te doen. Het enige wat je moet doen in zorgen dat het Ip adres klopt en de DHCP instellen zodat dit overkomt met de omgeving. Bij een AD omgeving zorg je ervoor dat de DHCP uitgedeeld word door de server. Hiervoor gebruik je een DHCP relay. Stel deze in op het ip adres van de server.
Voor een Entra ID omgeving zorg je ervoor dat de Watchguard de DHCP uitdeelt. Maak hiervoor een DHCP pool aan van 192.168.10.100-192.168.10.200.
- De external poort moet je eerst inventariseren wat voor verbinding ze hebben. Hebben ze een VDSL verbinding of DSL verbinding kan je deze op DHCP laten staan. Hebben ze een FTTH verbinding dan zal je in meeste gevallen nog een VLAN moeten instellen. Om dit in te stellen ga je bovenin Network configuration naar VLAN. Maak hier een VLAN aan en geef deze een gepaste naam. Zet de security zone op External en vul de VLAN ID in naar behoren. Vink Use DHCP Client aan. 
- Onder de External poort druk je nu op configure, zet de interface type op VLAN en selecteer de VLAN die je zojuist gemaakt hebt.

#### Instelllen van een 5G Failover
- Voor een 5G failover verbinding moet er een extra poort ingesteld worden. Kies een optional poort en configureer deze als volgt
Name: 5G Failover
Interface Type: External
Use DHCP Client
- Wanneer de poort ingesteld is moet je deze verder configureren onder Multi-WAN. Onder Multi-WAN configuration laat je deze op Failover staan. Onder Configure zet je de hoofdverbinding naar boven en de 5G verbinding altijd daaronder. Ander gebruikt hij de 5G verbinding als primaire verbinding. Onder Failback for Active Connections zet je deze op Gradual failback: Allow connections to use failover interface.
- Nu stellen we de link monitor in. De link monitor stuurt een ping naar een DNS server toe zoals 1.1.1.1 om te kijken of de verbinding nog online is. Wanneer de ping stopt zal hij overschakelen naar de failover verbinding. Onder monitored interfaces voeg je de primaire verbinding toe. Hier kies je nooit de 5G verbinding! Hierna vul je onder settings de DNS server in waarnaar je wilt pingen. 

## Watchguard Cloud Management

We beheren de Watchguard routers van onze klanten (ook niet serviceovereenkomst) via de Watchguard Cloud. Vooralsnog doen we dit alleen om de Firmware centraal te kunnen updaten. In de toekomst zullen we ook Policy's centraal uitrollen via dit systeem.

- Login op: [https://cloud.watchguard.com/](https://cloud.watchguard.com)
- SSO login met IDP name **SupracomBV**
- Bestaat de klant nog niet dan moet je deze aanmaken met exact dezelfde naam als in HaloPSA
- Klik in de linker kolom eerst op **Overview**
- Via **Inventory** ga je naar **Unallocated** en klik je je toegevoegde Firebox aan en koppelt deze aan de klant
- Klik in de linker kolom nu op de klantnaam
  - Ga naar **Configure > Devices**. Hier kun je nu het device toevoegen
  - Kies bij **Device Management** voor **Local Managment** anders wordt je lokale configuratie gewist.
  - In principe hoef je niks te doen met verificatie als je FW up to date is (> v12.0) De rest doe je vanaf de Firebox.

  ## PRTG Monitoring
Je bent bezig met de installatie van een router die verbonden zal worden met het internet. Vanwege onze dienstverlening is het noodzakelijk om de internetverbinding(en), indien nog niet gebeurd, op te nemen in de monitoring.

Volg hiervoor het volgende artikel: [WAN monitoring met PRTG](https://bookstack.supracom.stellarhosted.com/books/monitoring/page/wan-monitoring-met-prtg).

#### Oude Firebox verwijderen
Wanneer een Firebox vervangen wordt, moet de oude verwijderd worden uit het productoverzicht

- Verwijder de Firebox uit de Watchguard Cloud
- Ga vervolgens naar [https://myproducts.watchguard.com/manage-products](https://myproducts.watchguard.com/manage-products)
- Zoek het device op en klik op **Retire**

## SSL VPN met DUO MFA via RADIUS
Het is mogelijk om VPN verbindingen naar een Watchguard firewall te beveiligen met MFA. Hier is wel een lokale Active Directory omgeving voor nodig, omdat dit via RADIUS loopt.

- In het volgende Watchguard artikel staat alles uitgelegd: [https://www.watchguard.com/help/docs/help-center/en-US/Content/Integration-Guides/General/duo-security-authentication.html](https://www.watchguard.com/help/docs/help-center/en-US/Content/Integration-Guides/General/duo-security-authentication.html)

- Wanneer je binnen de Watchguard de RADIUS Authenticator Server toevoegt, zorg ervoor dat het vinkje bij: Require the Message-Authenticator Attribute UIT staat. 


## SSL VPN met Entra MFA

##### Voorwaarden
-	Lokale AD server met Entra Cloud Sync (Niet te verwarren met Entra/Azure AD Connect)
-	NPS server geïnstalleerd met **MFA PS extension**
-	AD security group **SSLVPN-Users**
-	Tenant minimaal **Entra P1** capable
-	Radius poorten open in firewall server
-	De gebruiker logt in met de volledige UPN (gebruikersnaam@domeinnaampraktijk.nl)

##### Installatie NPS en RADIUS server
Als voorbereiding installeer je de **Network Policy and Access Service** rol via de **Server Manager**

Configureer deze met de volgende opties:

**Radius Client**
- Friendly name: **Watchguard**
- Address: IP van de watchguard, bijvoorbeeld **192.168.10.1**
- Shared secret: genereren en in ITglue opslaan

**Policies**
Volg de wizard voor een nieuwe Network Policy
	
- Policy name: **Watchguard**
- Condition: User group (Bijvoorbeeld **AD\SSLVPN-Users**)
- **Access granted**
- EAP Types: Voor SSLVPN is een vinkje bij PAP voldoende. Rest default laten.
- Constraints: default laten
- Settings: **Standard** add (Filter-Id = **SSLVPN-Users**)

##### Installatie watchguard
Voeg op de watchguard onder Authentication servers een RADIUS server toe.
- IP Address: Het IP van de NPS server
- Port: 1812
- Shared Secret: De shared secret die in IT glue staat die gemaakt is op de NPS

Controleer nu of je in kunt loggen op de VPN met een ad gebruiker (let op, log in met een UPN). Nadat de MFA extensie is geïnstalleerd is dit deel troubleshooten lastig.
Gelukt? dan installeren we nu de MFA extensie op de NPS service:

[Download NPS Extension for Azure MFA from Official Microsoft Download Center](https://www.microsoft.com/en-us/download/details.aspx?id=54688)

##### Configuratie MFA Extensie
Na de installatie van de plug-in moet deze geconfigureerd worden. Dit kan met behulp van Powershell en het bijbehorende script:

```
cd "C:\Program Files\Microsoft\AzureMfa\Config"
.\AzureMfaNpsExtnConfigSetup.ps1
```

Als je de prompt krijgt log je in met de Global Admin. Voer tijdens de installatie ook de Tenant-ID in.

Als het script succesvol uit is gevoerd wordt dit aan het eind ook weergegeven. 

De RADIUS server kan niet overweg met TOTP en dus zal elke validatie falen. Hiervoor stellen we een push bericht in in de MS Authenticator. Deze is vergelijkbaar aan DUO en werkt wel in een keer goed.

Open het register en browse naar:
```
Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\AzureMfa
```

Voeg nu de volgende String Value toe:
```
OVERRIDE_NUMBER_MATCHING_WITH_OTP (Value data: FALSE)
```

##### Testen:
Log nu in met een gebruiker die de juiste Entra P1 licentie heeft en ook MFA in de MS Authenticator app heeft geregistreerd. 
De App zal een push bericht geven en na akkoord zal de connectie tot stand komt. Dit laatste stuk kan wel 10 sec duren.

##### Troubleshooting:
Onderzoeken waarom een gebruiker niet in kan loggen kan lastig zijn omdat een deel van de verificatie in Entra plaatsvindt. 
Er zijn een paar trucjes die het makkelijker maken:

De eerste is het tijdelijk uitschakelen van de MFA plugin. Hierna is het NPS windows log duidelijker te lezen. Dit kun je doen door een backup te maken van de twee sleutels die in het volgende register pad staan. Verwijder vervolgens deze sleutels en herstart de NPS service.
```
Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AuthSrv\Parameters
```
[![](https://bookstack.supracom.stellarhosted.com/uploads/images/gallery/2025-03/scaled-1680-/TZookIFVUzYHPquS-image-1741952582246.png)](https://bookstack.supracom.stellarhosted.com/uploads/images/gallery/2025-03/TZookIFVUzYHPquS-image-1741952582246.png)

Na een succesvolle herstart vind je in de Windows logboeken een duidelijkere aanwijzing waarom een gebruiker niet in kan loggen.

De NPS logboeken kun je vinden in de **Event Viewer > Custom Views > Server Roles > Network Policy and Access Services**

Zet de registersleutel terug en herstart de NPS service om de push weer te testen.

Wil je weten of een gebruiker wel juist heeft gereageerd dan vind je dat in het volgende logboek: **Applications and Services Logs > Microsoft > AzureMfa > AuthZ > AuthZOptCh**

Er is een video die veel voorkomende fouten/oplossingen laat zien: [(146) Basic NPS and MFA extension troubleshooting - YouTube ](https://www.youtube.com/watch?v=EHvqMEjorJk&t=594s)

##### Bronnen:
[Use Microsoft Entra multifactor authentication with NPS - Microsoft Entra ID | Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-mfa-nps-extension)
[Azure MFA with NPS extension — WatchGuard Community](https://community.watchguard.com/watchguard-community/discussion/3829/azure-mfa-with-nps-extension)
[Configure Windows Server to authenticate mobile VPN users with RADIUS and Active Directory](https://techsearch.watchguard.com/KB/WGKnowledgeBase?lang=en_US&SFDCID=kA22A000000XZlhSAG&type=KBArticle)



## In- of uitschakelen web-interface SSL VPN
Om de diverse aanmeldpogingen te limiteren welke gegenereerd worden door onze vrienden uit twijfelachtige landen, kunnen we de web-interface van de SSLVPN pagina in- of uitschakelen. Vanaf versie 12.11 is dit helemaal niet meer beschikbaar. Dit is verwijderd in de firmware.

<p class="callout warning">Let op, dit is niet meer nodig als je de nieuwste firmware hebt en de functie Block failed logins aan hebt staan.</p>

- Maak vanuit LAN een SSH verbinding naar de WatchGuard. Dit kan zonder extra tools (mits up-to-date Windows Server) vanuit je Windows CLI.

   ```
   ssh admin@192.168.10.1 -p 4118
   ```

- Om de web-interface uit te schakelen graag de volgende commando's gebruiken

   ```
   WG# config
   WG(config)# policy
   WG(config/policy)# no sslvpn web-download enable
   ```

- Om de web-interface weer in te willen schakelen kan je de volgende commando's gebruiken

   ```
   WG# config
   WG(config)# policy
   WG(config/policy)# sslvpn web-download enable
   ```