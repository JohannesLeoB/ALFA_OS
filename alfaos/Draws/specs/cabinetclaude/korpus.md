# Korpus

Maße mm. Breite/Höhe/Tiefe wählbar aus Liste, Fett = Standard (Pack). Jede positive Größe zulässig.
Status: Typ im Pack = Daten; ohne Zeile in Pack = offen.

| Art | Pack-Kind | Breiten | Höhen | Tiefen | Standardfront | Hinweis | Status |
|---|---|---|---|---|---|---|---|
| Unter | base | 200 300 400 **600** 800 | **800** | **600**, 370 | Tür (ab 800 Paar) | Platte, Sockel | gebaut |
| Spüle | base | 600, 800 | 800 | 600 | Tür/Auszug + Einlass sink | Einlass in Platte | gebaut |
| Kochfeld | base | 600, 800 | 800 | 600 | Auszüge + Einlass hob | Abstand Wand | gebaut |
| Backofen-Unter | base | 600 | 800 | 600 | Gerät oven + Schublade | Nische 600 hoch | gebaut |
| Geschirrspüler | base | 600 | 800 | 600 | Gerät dishwasher | Klappfront | gebaut |
| Eck Blind | cornerBase | 1280 | 800 | 680 | Tür | Blindteil | gebaut |
| Eck L | cornerBase | 880 | 800 | 880 | Tür | | gebaut |
| Wand | wall | 200 300 400 **600** 800 | 400 600 **800** 1000 | 370 | Tür | | gebaut |
| Wand-Eck | cornerWall | 675 | 600 **800** 1000 | 675 | Tür | | gebaut |
| Dunstabzug | wall | 600, 800 | 400-600 | 370 | Klappe/Tür | kein eigener Typ | offen |
| Hoch | tall | 400 **600** 800 | 1400 **2000** 2200 | **600**, 370 | Tür | trägt Aufsatz | gebaut |
| Hoch-Kühl | housing | 600 | 1400 **2000** 2200 | 600 | Gerät fridge | belüftet | gebaut |
| Hoch-Backofen | housing | 600 | 2000, 2200 | 600 | Gerät oven + Türen | Front mit Fix-Höhe | gebaut (front-Liste) |
| Aufsatz | top | 400, 600 (= Host) | **400**, 600 | 600 | Tür | sitzt auf Hoch (mount stack) | gebaut |
| Offen/Regal | open | **200** | 400 **600** 800 | 370 | keine, Böden alle 300 | hohl, 5 Platten | gebaut |
| Insel | base in island | wie Unter | 800 | 600 | beidseitig | Rückseite Blende | Zeile gebaut, Rückblende offen |
| Halbhoch | kein | 400-800 | 1000-1400 | 600 | Tür | | offen |

Hinweise
- Standardfront Hoch-Kühl/Geräte: Pack kinds.housing.front = fridge.
- Eck Blind: Tiefe über cornerDepths je Breite (gebaut, :125).
- Aufsatz ohne tragenden Vorgänger = Fehler host (gebaut, :120).
