# Lastenheft Konfigurator (Canvas)

Wie ein Profi-Konfigurator (CAD-Innenraum-, Web-Schrank-, Fahrzeugkonfigurator): jeder Schrank wird im Canvas direkt eingestellt. Nur Typen; Breite, Höhe, Tiefe, Front- und Innenteilung und Anordnung sind frei. Startwerte kommen von der Person (Voreinstellungen, später ALFA-Einstellungen). Status: gebaut (Datei:Zeile) / teilweise / offen. Stand 23.10.

| Nr | Anforderung | Status |
|---|---|---|
| KF-01 | Auswahl: Klick wählt einen Schrank (nicht Blatt-Zelle), Hervorhebung, Mehrfach mit Umschalt; Klick ins Leere hebt auf | teilweise: nur Blatt-Zellen DrawsModel.swift:122, Lanes.swift:177; Schrank-Auswahl offen |
| KF-02 | Inline-Editor per Doppelklick auf einen Schrank | gebaut Lanes.swift:176, Editing.swift:29 |
| KF-03 | Editor deckt Breite, Höhe, Tiefe, Fronten (Notation); Return übernimmt, Esc bricht ab | gebaut Editing.swift:106; Typ, Innenteilung, Anordnung, Material, Merkmale fehlen: teilweise |
| KF-04 | Kontextmenü (Zweitklick) auf Schrank | offen |
| KF-05 | Menü: Typ wechseln | offen |
| KF-06 | Menü: Teilungs-Voreinstellungen (Tür, Paar, 2/3/4 Auszüge, offen, Glas) | offen |
| KF-07 | Menü: Anschlagseite spiegeln | offen |
| KF-08 | Menü: links oder rechts einfügen | offen |
| KF-09 | Menü: duplizieren, löschen | offen |
| KF-10 | Menü: Material und Merkmale überschreiben; auf gemeinsam zurücksetzen | offen |
| KF-11 | Tastatur auf gewähltem Schrank: Pfeile verschieben (Zeile bleibt bündig) | offen |
| KF-12 | Tastatur: Breite in Schritten ändern, mit Zusatztaste fein | offen |
| KF-13 | Tastatur: nächster und vorheriger Schrank (Tab, Umschalt-Tab) | offen |
| KF-14 | Tastatur: duplizieren, löschen | offen |
| KF-15 | Rückgängig und Wiederholen je Eingabe (auch G-33) | offen |
| KF-16 | Live-Neuaufbau nur dieses Schranks; Nachbarn rücken | gebaut Editing.swift:58 (beim Übernehmen, nicht während der Eingabe: teilweise) |
| KF-17 | Mehrfachauswahl: gemeinsame Änderung (Höhe, Tiefe, Material, Merkmale) auf alle | offen |
| KF-18 | Voreinstellungen je Typ als Startwerte (Maße, Front, Innenleben), später aus ALFA-Einstellungen | teilweise: Pack presets/carcass.json, nicht durch die Person änderbar |
| KF-19 | Gemeinsamer Satz für die Küche: Merkmale (Griff- oder Grifflos-Strategie, Frontstil, Kante, Sockelart) und Materialien (Front, Korpus, Platte) | teilweise: Schrank-Material KitchenSpec.swift:35; Merkmale offen |
| KF-20 | Je Schrank überschreiben; ohne Überschreibung gilt der gemeinsame Satz | teilweise: material, frontMaterial je Schrank KitchenSpec.swift:35, ohne Bedienung |
| KF-21 | Materialmuster aus der Medienbibliothek der Firma über den Hub (hub-needs.md) | offen |
| KF-22 | Alle Werte der Oberfläche aus Design-Tokens; was fehlt, wird Design-Bedarf (design-needs.md) | teilweise: Editor nutzt Tokens (Editing.swift:106); Menü, Auswahl, Muster ohne Wert: Design-Bedarf |

Hinweise
- Keine Marken, Hersteller oder Produkte in Daten und Texten.
- Jede neue Anforderung bekommt einen Test mit Mutant (G-44).
