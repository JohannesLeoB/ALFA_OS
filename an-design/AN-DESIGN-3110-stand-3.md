# Code → Design · Stand 3 · 31.10.2026 abends (Auftrag von Johannes: „Design anpoken und Lieferung erbitten“)

Stand `main` 1ed575ec, Master 2910. Hier steht alles, was Code seit der Übernahme von 2910 **ohne Bogen erfunden, selbst entschieden oder textlich abweichend** gebaut hat und noch nicht gemeldet war. Ergänzt `AN-DESIGN-3110-stand-2.md` (Fragen 1 bis 6) und `AN-DESIGN-3110-intro.md`.

## A · Texte ohne Master-Key (bitte Key liefern oder ersetzen)
| Key | de (heute) | Wo |
|---|---|---|
| `google.oauth.accepted` / `microsoft.oauth.accepted` | Google-/Microsoft-Anmeldung übernommen | Titel der Intro-Seite |
| `google.oauth.unreadable` / `microsoft.oauth.unreadable` | …-Anmeldung nicht lesbar | Fehlerseite nach Anmeldung |
| `shell.signin.close` | Dieses Fenster kann jetzt geschlossen werden. | Intro-Seite |
| `shell.signin.retry` | Bitte in ALFA_OS erneut anmelden. | Fehlerseite |
| `assistant.prompt.identity` | Du bist der ALFA_OS-Projektassistent … | Systemtext an Claude, nicht sichtbar |
| `settings.usage.prices.missing` | Preise fehlen … dann schätzt ALFA_OS die Kosten. | Einstellungen › Claude › Verbrauch |

## B · Texte, die vom Master abweichen
- **Name „ALFA_OS“ statt „ALFA“** (Johannes' Entscheidung 31.10.): `mail.later.missed`, `mail.later.notice.title`, `mail.later.notice.text`, `settings.account.serverCopy.deleted`. Bitte in den nächsten Master übernehmen.
- Platzhalter heißen im Code `{1}` statt `{when}`, `{sender}`, `{domain}` (`mail.later.planned`, `mail.toast.unsubscribed`, `settings.account.foundText`); der Wortlaut ist gleich.
- Entfernt: `text.settings.provider.other` („Andere“, ersetzt durch „Anderer Anbieter“ aus dem Master) und `shell.assistantScope.home` („Ohne Projekt“, L3).

## C · Verhalten ohne Bogen, von Code entschieden
**Einstellungen**
1. „Neu verbinden“ öffnet bei einem **verbundenen** Dienst das Formular; ein neuer Schlüssel ersetzt die Verbindung an Ort und Stelle (Johannes 31.10.). Den Knopf „Prüfen“ gibt es bei den Diensten damit nicht mehr, nur noch bei Mailkonten.
2. Das Schlüssel-Formular verlangt alle Pflichtfelder (auch ohne Geheimnis, z. B. Clockodo-E-Mail, Airtable-Base) und zeigt sonst „Bitte prüfen: fehlt …“; optionale Felder (DHL) dürfen leer bleiben.
3. Konto anlegen: Gmail fehlt im Anbieter-Menü (läuft über die Google-Karte); „Kontotyp“ erscheint nur, wenn die Suche IMAP und POP findet; „Neu anmelden“ bei einem bestehenden Konto zeigt das ganze Formular ohne Schritte.
4. Logos: Der Grund (claudeClay, sevdeskRed, clockodoBlue, dhlYellow, sonst sheet) wird je Dienst gewählt; die Größe „Bildmarke Feld 28 → 16“ hat in der App noch keinen Ort.
5. Mail-Abgleich: „Mail n von m“ zählt über alle Ordner eines Kontos zusammen.

**Später senden**
6. Die Voreinstellungen „Heute, 18:00“, „Morgen, 8:00“, „Montag, 8:00“ formatiert das System (keine Keys). „Heute 18:00“ nur vor 18 Uhr; ist morgen Montag, wird der Montag der Folgewoche angeboten.
7. „Geplant · {when}“: heute/morgen relativ, innerhalb einer Woche Wochentag mit Uhrzeit, später Datum mit Uhrzeit.
8. Verpasste Mails werden beim Start erkannt; im Ordner wählt ein Einzelklick nichts aus, ein Doppelklick bearbeitet.

**Mailingliste**
9. Abmelde-Mail ohne Betreff geht mit Betreff „unsubscribe“; der Zustand „Abgemeldet“ gilt nur, solange die Karte offen ist; das Banner erscheint erst bei Mails, die nach dem Update geladen wurden.

**Verfassen**
10. Beschriftung „10 s“, „20 s“, „30 s“ formatiert das System.

**Intro-Seite und Blob-Link** (Details im Intro-Auftrag)
11. Sequenz, Verzögerungen, Zweiklang, Hover und Fokus des Blobs sind Übergang.

## D · Bitte liefern
1. **Bogen Bestätigen** (fehlt in 2910).
2. **Bogen „ALFA Intro.dc.html“** mit Markenbotschaft (`AN-DESIGN-3110-intro.md`).
3. **Bereich A des Assistenten** (`AN-DESIGN-3110-assistent-mail.md`).
4. **Teamansichten T1 bis T4** (`AN-DESIGN-3110-rollen.md`).
5. **M1 bis M9** und **R1 bis R5**.
6. **Antworten auf die Fragen 1 bis 6** aus `AN-DESIGN-3110-stand-2.md` und Stellungnahme zu C1 bis C11.
7. **Keys** für Teil A und die Texte, die das System heute formatiert (C6, C7, C10).
8. **L5, L6:** Stand bei Design?

Alles als neuer Master-ZIP über Johannes.

## E · Nachtrag: Blob der Anmeldeseite nach dem Master (`main` 3ce69713)
- Nachgebaut aus `ALFA Shell.dc.html`: voller Ring in currentColor, Lider (`size.blobLidOffset`, öffnen mit `duration.blobEyes`), Augen folgen der Maus nach der Formel der Shell (Zeile 202, `blobEyeFollowDistance`, `blobEyeFollowRamp`, `blobEyeTravelX/Y`), Schrift Geist aus dem App-Bundle, Label 13 px/500. Der erfundene Hover ist entfernt.
- **Widerspruch im Master:** Die Pille im Dunkelmodus ist in `contract/theme-dark.tokens.json` #f5f5f5 (Code folgt dem), in `project/alfa-theme.css` aber #2e2e2e. Welcher Wert gilt?
- **Weiter erfunden:** Skalierung des Blobs ×2 auf der Seite, alle Startzeitpunkte, Lider-Startwert scaleY .45, Blinzeln scaleY .1 einmal bei 1,7 s statt im Zufallsintervall der Shell, Label-Breite 200 px, der Zweiklang.
