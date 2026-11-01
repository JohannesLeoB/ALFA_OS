# Code → Design · Texte und Bögen, die fehlen · 01.11.2026 (Stand `main` a0e2553e)

Aus dem Klick-Audit, dem Text-Abgleich mit Master 2910 und der Fehler-Härtung. Code hat nichts davon erfunden; überall steht vorerst ein vorhandener, allgemeiner Text oder gar nichts. Freigegeben von Johannes im Chat am 01.11. („update designchannel!“).

## A · Fehlende Texte (Code nutzt bis dahin „Keine Antwort“ bzw. den allgemeinen Fehlertext)
1. Preisanker konnten nicht geladen werden (Kalkulation).
2. Protokoll konnte nicht gespeichert werden (Integrations-Log; derzeit gar nicht angezeigt).
3. Datenschutz-Einstellungen nicht lesbar – darum ist alles gesperrt (Chat und Einstellungen).
4. Kontakte konnten nicht gespeichert werden (derzeit gar nicht angezeigt).
5. „Keine Antwort“ (`settings.failed.unknown`) erscheint auch bei Fehlern, die keine Zeitüberschreitung sind: Speichern von Datenschutz, Kontaktquelle, Kontakte aktualisieren, Schlüssel speichern/löschen, Projektordner, Einstellungen schreiben, Anker speichern, Vorlagen lesen, Neustart nach Abmelden, Konto entfernen, Fehlerzeile der Dienstkarte. Bitte einen Text für „Speichern/Schreiben fehlgeschlagen“ und einen für „Lesen fehlgeschlagen“.
6. Rückfrage „Kontakt entfernen?“ für die Halte-Pille in der Kontakte-Karte.

## B · Fehlende Bögen
1. Bestätigen-Karte des Assistenten (Mail, Termin, Kontakt, Aufgabe, Warenkorb): Karten haben keinen Knopf, es wird nichts angelegt.
2. Einstieg in die Karte Kontakte (heute nur über einen gespeicherten Kontakt erreichbar).
3. Dateiordner-Zeilen „Projektordner“, „Projektdaten“, „Vorlagen“: nur Werte, keine Aktion – Sprung zur zuständigen Karte?
4. Geplante Mail (Später senden): Öffnen ohne die Planung aufzuheben, Kontextmenü (Bearbeiten, Planung aufheben, Jetzt senden).
5. ClickUp „Phasen“ und „Aufgabenfelder“ sind im Code eine Einstellung – zwei Bereiche oder einer?
6. Tooltip „Gerade abgeglichen“: zeigt immer dasselbe – mit Zeitangabe?

## C · Master-Texte ohne Stelle in der App (keine Oberfläche gebaut)
Anheften (`mail.symbolButton.pin.aria`), Stapel-Knopf (`mail.button.s015`), Als Vorlage gesichert (`mail.feedback.s014`), Bild wählen, Teams, Absendername, Abmelde-Details, Projektordner gewählt, Nutzung seit …, Schätzwerte, PDF gesichert · Projekt · Korrespondenz, Anhang kopiert · Projekt · Anhänge, Kopie entfernt, Backup- und Vorlagen-Texte (`settings.button.s011/s013/s017`, `settings.label.s010…s070`). Zu welchen Bögen gehören sie?

## D · Hinweise zum Vertrag
- Platzhalter: Die App nutzt positionell `{1}`, `{2}`; der Master benannt `{count}`. Der Wortlaut ist gleich. Bitte im nächsten Master positionell oder eine Zuordnung liefern.
- Mehrere Master-Schlüssel mit gleichem Text sind in der App auf einen Schlüssel zusammengelegt (z. B. Erneut versuchen, Abbrechen, Senden, Rückgängig). Beim Abgleich als Alias lesen.
- „ALFA“ im Master an vier Stellen bleibt in der App „ALFA_OS“ (Johannes 31.10.).

## E · Seit dem Bericht 669d1a97 sichtbar geändert (Johannes 01.11.)
- Fehlerzeilen zeigen nur noch den deutschen Text; die technische Ursache steht im Tooltip und im Protokoll (`a303a3a5`).
- Sind die Datenschutz-Einstellungen nicht lesbar, ist alles gesperrt statt offen (`e04136c0`). Dafür fehlt der Text aus A 3.
- Kategorie „Dateiordner“ heißt im Code jetzt so (`settings.section.folders`); Schlüssel `mail.deck.showNew` heißt `mail.deck.showUnread`, der Text ist gleich.
- Kein neuer Bau seit 1024; der nächste Bau kommt nur auf Johannes' Wort.

## F · Nachtrag Textabgleich (01.11. abends)
- 349 von 422 Master-Texten sind in der App (gleicher Schlüssel oder gleichlautender Alias); 72 gehören zu nicht gebauten Elementen oder sind Beispieldaten. Deutsch blieb unverändert, Englisch an 8 Schlüsseln angeglichen (`cfd793d1`).
- Vermutlich Fehler im Master: `shell.assistantCard.kind.appointment` hat als Englisch „Termin“. Die App behält „Appointment“.
- Bewusst abweichend: `mail.toast.projectSaved` und `mail.attachment.copied` nennen im Master Unterordner („Korrespondenz“, „Anhänge“), die der Code nicht anlegt. Gibt es diese Unterordner, oder gilt der Projektordner selbst?
