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
- Offen: Erst-Setup; BOGEN-EINSTELLUNGEN 1.8.2 „proposal“, Sperre „Nur Verwaltende“ (BOGEN-EINSTELLUNGEN.json:354–357) gegen sein Wort; `alfaos/Config/company.example.json` (60 Zeilen, ohne Werte) listet die Firmenwerte, die ALPHA fest brauchte (16 Airtable-Basen, 28 Tabellen, 12 Felder); wohin sie in Einstellungen oder Onboarding kommen, ist offen.
- Gefunden 19.10.: Dienste und Aufgaben „Genutzt von“ (TEXTE-EINSTELLUNGEN.json:1448-1476, decided): Google Mail/Drive/Kalender/Kontakte, ClickUp Aufgaben/Listen, Clockodo Zeit/Buchungen, sevDesk Angebote/Kunden/Belegnummern („nur für angebotsentwürfe“, 08.10., ASSUMPTIONS A475), Claude Assistent, DHL Label/Sendungen, Happa Happa Speiseplan; 15 Integrationen „Ja, so (Empfehlung)“ (16.10. 21:05 97326b1d); Vorlagen = Dokumentvorlagen für Editoren (Moodboard, Aufmaß, PDF, DXF, Logos, Fonts) in den Einstellungen (22.09. 19:06 labor; 26.09. 23:52 ffde6a84); Ersteinrichtung: lokaler Ankerordner, Ort Projektordnerbaum, Daten, Vorlagen (04.10., A341, A344), Wiederholung „nur leere Felder füllen“ (A357), Google und ClickUp „Ein Weg für beide“ (A365); App-Sperre „Auch erneut nach Pause“ (04.10., A351), Touch ID (TEXTE-EINSTELLUNGEN.json:694-698); Gruppen „Nach Integrationen, Einstellungen Nutzer, view, etc - nicht Mac OS Standard“ (05.10., A388), „Zwölf Abschnitte in fünf Gruppen (Inhalt)“ (13.10., entscheidungen.md:133); Assistent: „Lesen: Projekte, Zeiten, Belege … Schreiben auf Bestätigung, Dateien erzeugen und ablegen“ (21.09. 00:46 labor), „er darf alles sehen“ (09.10. 17:36 ALLFARBEN 9740c1c5), Kundendaten nicht an US-KI (08.10., A471); Vollbild „no window buttons“ (05.10., BOGEN-GLOBAL.json:539), Blob-Lage wird gemerkt (:533). Offen: Datenschutz-Export (zwei widersprüchliche Texte TEXTE-EINSTELLUNGEN.json:1684/:1696); welche fünf Gruppen; Startbereich nach dem Start.
