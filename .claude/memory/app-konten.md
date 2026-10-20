---
name: app-konten
description: "Funktionskarte Konten, Einstellungen, Hub (Dienste, Rechte, Integrationen): Ist, Soll, Offen, Stand 18.10."
metadata:
  node_type: memory
  type: project
  originSessionId: c2a04c8a-08ac-42dc-b4d2-3f9732b7dd70
  modified: 2026-10-18T16:57:49.160Z
---

Funktionskarte (Stand 18.10.; Ist = Bestand, Soll = sein Wort, Offen = belegte Frage)
Konten, Einstellungen, Hub
- Ist: ALPHA: 6 Dienste verbunden (Google, Airtable, ClickUp, sevDesk, Claude, Clockodo; `~/ALPHA/BAUSTELLEN.tsv:8`). ALFA_OS: `alfaos/App/Settings`, `Kit/Sources/Hub`.
- Soll: „es wird der HUB der die ganze App belegt und fließen lässt“ (12.10. 14:54 a9bb817c); „…es seih denn die FIRMA (Admin )  sperrt das für einzelne Dienste, aber NICHT DU.“ (12.10. 17:40 a9bb817c); „Rollen als Einstellung (Recommended)“ (10.10. 22:20 7cc894d9); „WIE die rollen gegated sind etc - das machen wir Später!!!“ (13.10. 20:56 97326b1d); „fehler/Eingeschränkt/onloine einwandfrei in drei Iconen/zuständen“ (12.10. 20:23 7cc894d9); „bis 15 volle tiefe mit allen options und voller wire“ (16.10. 20:52 97326b1d); „Fest verdrahtetes STRIKT raus aus dem Code und als Auswahlpfade oder User Setups in die App Einstellungen und/oder Onboarding udn Presets legen“ (26.09. 23:43 ffde6a84).
- DHL (Johannes 20.10.): „SANDBOX Raus. DHL ist per API angebunden zu "DHL Tracking" und "DHL Shipping". Es ist eine "Integration wie alle anderen. DHL kann Labels erstellen, drucken etc. In mylikos alpha App bereits seit monaten funktional drin. Bitte DHL als EINE Integration mit Widget auf dem "Heute" Board" (folgt später, ist quasi "dashboard/startseite der App)“. Folge: Sandbox-Zugang aus `fundus/alpha/Sources/AlfaServices/Sendungen/DHLVersandClient.swift:53-55` entfernen; Versand-Code bleibt und wird angebunden; eine Kachel statt `dhl`/`dhlship`.
- Hub und Mail (Johannes 20.10. 21:51 Berlin, Produkt-Sitzung 3f52450e): „Hub/Einstellungen & Mail weiter heben und sämtliche Funktionen beleben. Code muss Lastenheft an Funktionen liefern.“ und „HUB ist dabei der "Netzwerkstecker" zu allen Apps, Units, Modulen“.
- Offen: Erst-Setup; BOGEN-EINSTELLUNGEN 1.8.2 „proposal“, Sperre „Nur Verwaltende“ (BOGEN-EINSTELLUNGEN.json:354–357) gegen sein Wort; `alfaos/Config/company.example.json` (60 Zeilen, ohne Werte) listet die Firmenwerte, die ALPHA fest brauchte (16 Airtable-Basen, 28 Tabellen, 12 Felder); wohin sie in Einstellungen oder Onboarding kommen, ist offen.
