## Instellen van de exception

# Apps blokkeren wanneer autopilot draait
Onder Requirements voeg een een rule toe. Kies voor Script en voeg het script toe. Onder Select output data type kies je voor String > Operator: Equals.
Onder Value voer je het volgende in: Windows Autopilot ESP Not Running

# Apps enkel toestaan voor installatie tijdens Autopilot
Onder Requirements voeg een een rule toe. Kies voor Script en voeg het script toe. Onder Select output data type kies je voor String > Operator: Equals.
Onder Value voer je het volgende in: Windows Autopilot ESP Running