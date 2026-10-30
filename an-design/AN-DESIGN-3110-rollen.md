# Aufträge an Design – Rollen und Firmenregeln, 31.10. (von Johannes am 31.10. freigegeben)

Grundlage: Master 28.10., Einstellungen (ALFA Einstellungen.dc.html). Gebaut ist die Logik (Branch JO/charming-elgamal-44e5b6, Commit 48dcceae): Die Firmenregeln kommen aus company.json, der Assistent hält sie ein. Es gibt noch keine Ansicht dafür; der Master hat keinen Bogen.

## R1 Rolle und Admin-Entsperrung
- **Ist (Bogen 28.10.):** Das Profil zeigt „Rolle“ nur als freien Text (Beispiel „Gestaltung, Leitung“). Eine Rolle im Sinn von Rechten kennt der Bogen nicht.
- **Code kann schon:** Zwei Rollen, Admin und Mitarbeitende. Admin ist ein Mac, an dem in company.json `team.role = admin` steht. Dort lassen sich die Firmenregeln nach Touch ID oder Passwort ändern. Auf allen anderen Macs sind sie nur lesbar.
- **Gebraucht:**
  - Eine Anzeige der Rolle (Admin oder Mitarbeitende).
  - Ein Zustand „Regeln entsperren“ mit Touch ID oder Passwort, im Stil der App-Sperre.
  - Der Zustand „entsperrt“ und die Rückkehr in „gesperrt“.

## R2 Zeile „vom Admin festgelegt“
- **Ist:** Alle Schalterzeilen in Datenschutz und Claude-Karte sind für jeden frei einstellbar.
- **Code kann schon:** Eine Firmenregel sperrt eine Kategorie, Dateien im Chat, die Modellwahl oder die Zugriffsstufe. Für den Nutzer gilt: Er kann nur enger stellen, nie weiter.
- **Gebraucht:**
  - Eine Zeilenform für „gesperrt, weil die Firma es so festlegt“. Gesperrt, nicht ausgegraut (N20).
  - Ein kurzer Satz, wer es festlegt.
  - Dasselbe für die Auswahl des Modells: nur erlaubte Einträge.

## R3 Karte „Firmenregeln“ (nur für Admin)
- **Ist:** Die Gruppe Firma hat Firmendaten, Dateiordner und Vorlagen. Ein Abschnitt für Regeln fehlt in settings-sections.json.
- **Gebraucht:** Eine Karte mit diesen Zeilen:
  - Gesperrte Kategorien (Mail, Kalender, Kontakte, Drive, ClickUp, Notizen, Aufgaben, Katalog und Kalkulation, Studiowissen, Chat, Zeit) und Dateien im Chat.
  - Erlaubte Modelle (leer heißt alle).
  - Zugriffsstufe des Assistenten: nur lesen, nur vorschlagen (jede Aktion mit Außenwirkung braucht Bestätigung), auch schreiben.
  - Assistent für die Firma aus.
  - Verläufe löschen nach N Tagen (leer heißt nie).

## R4 Budget
- **Ist:** Die Claude-Karte zeigt Tokens, Preise und eine Schätzung.
- **Gebraucht:** Eine Warnschwelle in Euro und die Anzeige, wenn sie überschritten ist. Das ist nur ein lokaler Zähler dieses Macs; ein echtes Limit setzt nur die Anthropic-Konsole.

## R5 Zur Entscheidung durch Johannes (noch keine Ansicht bauen)
- Profilkopf mit Rollen-Badge und „aktiver Bewohner (dieses Gerät)“.
- Rollenvorlagen Accounting und Student.
- Team-Übersicht mit Anlegen und Sperren; braucht einen gemeinsamen Ort außerhalb der Macs.
- Wissen freigeben und vorschlagen; hängt am Assistenten-Bereich.
