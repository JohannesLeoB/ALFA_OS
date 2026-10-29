Export: 22.10.2026

# Antwort Design → Code · Nachtrag zu v12 (Brief 22.10.) · Stand 22.10.2026 01:50

Quelle der Fragen: Brief „Code → Design · Mail · Nachtrag zu v12“ (22.10.) und `.claude/memory/spec-mail.md` (MAIL-L13, L01, L10, L11, L12, L06). Alle Festlegungen unten sind **Design, kein Wort von Johannes** (set-by-design), außer wo ein Datum mit Wort steht. Bögen: `ALFA Mail.dc.html`, `ALFA Einstellungen.dc.html`. Vertrag: `contract/` (P1 valid, P2 consistent, P3 log matches, Block 2026-10-22T01:40). Zeigen im Bogen: Tweaks „Entwurf“ (draft), „Fehler“ (failure), „Mail“ (mail).

## L13 Entwurf schließen
Fundstellen: closeCard `ALFA Mail.dc.html:504`, saveThenClose `:522`, Kopf-Status `:694`, Status-Zeile `:759`, Hinweise `:765`, `:766`, Schließen-Knopf `:140`, Feldsperre `:503`.
- **a) Sichern scheitert** (Tweak draft „Sichern fehlgeschlagen“ / „Anmeldung abgelaufen“; failure „Entwurf schließen · Server/Anmeldung“): Die Karte bleibt offen. Text bleibt im Feld und im Arbeitsspeicher. Fehler: Hinweis in der Karte (card-notice-3, kind failure) mit Titel „Entwurf nicht gesichert“, Text „Der Server ist nicht erreichbar.“ bzw. „Die Anmeldung ist abgelaufen.“, Knopf „Erneut sichern“ bzw. „Erneut verbinden“; Kartenkopf und Statuszeile „Nicht gesichert“ (Signalfarbe). „Erneut sichern“ führt das Schließen zu Ende, wenn es von Schließen kam (`closeIntent`), sonst steht „Entwurf gesichert“. Verwerfen bleibt über die Pille im Fuß.
- **b) Postausgang oder Versandfehler** (draft „Im Postausgang“ / „Sendefehler“): Es wird nicht gesichert und nie „Entwurf gesichert“ gezeigt. Postausgang: Karte schließt, Toast „Im Postausgang“. Versandfehler: Karte schließt, Toast „Nicht gesendet · im Ordner Entwürfe“ mit Knopf „Erneut senden“. Beide Einträge erscheinen im Ordner Entwürfe mit „Im Postausgang“ bzw. „Nicht gesendet“ statt „Entwurf“ (`:422`); Öffnen stellt den Zustand wieder her (`:495`). Senden ohne Verbindung setzt den Zustand „Im Postausgang“ (`:537`).
- **c) Sichern läuft** (draft „sichert“; failure „Entwurf schließen · dauert“): Karte bleibt, Kopf und Statuszeile „Sichert …“ mit Spinner, Schließen-Knopf gesperrt (`disabled`), Felder gesperrt (Eingaben werden verworfen), zweites Schließen wirkt nicht. Ende: erfolgreich = Karte schließt, Toast „Entwurf gesichert“; Fehler = a).
- Texte: `mail.draftStatus.saving|notSaved|outbox`, `mail.notice.draftNotSaved.*`, `mail.toast.outbox|notSentInDrafts|resend`, `mail.draftList.notSent|outbox`. Bauteil-Zustände: `card-notice` (failure, closeSaveFailed, closeSaveAuth).
- **Fragen an Code:** (1) Zeitgrenze, nach der ein laufendes Sichern als gescheitert gilt (Design nennt keinen Wert). (2) Bleibt der Text beim Beenden der App erhalten? Wenn nein, braucht das Beenden eine Warnung wie „Postausgang nicht gesichert“. (3) Der Befund `MailModel+Draft.swift` (Sichern überschreibt `sendFailed`) bleibt Code: die Zeichnung sperrt Sichern in diesen Zuständen. (4) Eigener Ordner „Postausgang“? Heute gibt es keinen; der Bogen zeigt Wartende im Ordner Entwürfe.

## L-A Wähler für bis zu drei Postfächer (= L-009, MAIL-L01)
**Beantwortet: Wähler.** Johannes 19.10.: „Ich möchte lieber auf "Postfach" klicken und dort auswählen. Ein wirklich "schmal" gehaltenes Auswahlelement …“ (`entscheidungen.md`, 19.10.). Gezeichnet: Klick auf „Postfach“ im Kopf der linken Bahn fächert die Marken auf, gewählte gefüllt, „+“, Esc oder Klick daneben schließt (Elemente `mail.account-switch`, `mail.account-mark`, `mail.account-mark.pick`, `mail.account-mark.add`, `ALFA Mail.dc.html:17`). „Alle“ und Absenderzeile (ALFA Entscheidungen 9, 20.10.) sind Entwurf, nicht gebaut, nicht abgenommen. Der Master-Kopf zeigt nicht mehr nur ein Postfach.

## L-B Anhang: Vorschau, Drucken, Als PDF sichern (MAIL-L10)
Fundstellen: attMenu `:556`, pdfSave `:532`, Mehr-Menü `:731`.
- Johannes 22.10.: „Stelle das zu "PDF" bitte einfach als FRAGE zurück an Code, wenn das nativ MacOS26 und quasi "gratis onboard" ist, umso besser.“ Daher zeichnet Design **keine eigene Vorschau, keinen eigenen Druck- und Sichern-Dialog**: alles nativ (Quick Look, Druckdialog, Sichern-Dialog).
- Anhangmenü: Vorschau, `Drucken`, `Als PDF sichern` (nur bei Dateien, die Quick Look darstellt; Bogen: pdf, png, jpg, jpeg, gif, heic, txt als Platzhalterliste), Trennlinie, In anderes Projekt …, Sichern unter …. Ort der Datei: Wahl im nativen Sichern-Dialog, kein Vorgabeort von Design. Rückmeldung: Toast „Als PDF gesichert“; Fehler (failure „PDF sichern“): „PDF nicht gesichert“ mit „Erneut versuchen“; Anhang nicht ladbar: „Anhang nicht geladen“ (schon im Vertrag).
- **Fragen an Code:** Welche Dateitypen kann Quick Look/PDFKit? (Liste im Bogen ist Platzhalter.) Vorgabeordner des Sichern-Dialogs?

## L-C Ziehen und Ablegen von Anhängen (MAIL-L11)
Fundstellen: Zone `:198`, Handler `:762`. Zustand „Loslassen hängt an“ (draft „Ablegen“): gestrichelter Rahmen über dem Inhalt der Entwurfskarte (`mail.drop-overlay`, Text `mail.drop.over`), Symbol Datei. Loslassen hängt die Dateien an, Chips mit Name und Größe; Verlassen blendet die Zone aus. Gilt nur für die offene Entwurfskarte. **Frage an Code/Johannes:** Ablegen ohne offenen Entwurf (neuer Entwurf mit Anhang?) und zu große Mail (greift N4).

## L-D Regler der lokalen Mailablage (MAIL-L12)
Fundstellen: `ALFA Einstellungen.dc.html:252` (storeBlock), `:302` (Aufruf). Ort: Dienstkarte „Mail-Konten“, Block „Lokale Ablage“ (Johannes 15.10.: Mail-Konten und deren Optionen sind eine Integration). Zeilen: Zeitraum (30 Tage, 90 Tage, 1 Jahr, Alles), Anhänge lokal (Schalter, Vorgabe aus = Ist: Spiegel hält nur Kopfdaten, `MailMirror.swift:23-30`), Obergrenze (1, 5, 10, 25 GB, Keine), Ordner (Standard, Eigener Ordner; nativer Ordnerdialog). **Alle Optionswerte und Vorgaben von Design gesetzt, nicht von Johannes** (er nannte nur Zeitraum, Anhänge lokal, Obergrenze, eigener Ordner). Texte `settings.mailStore.*`. **Fragen:** Fehler- und Warnzustände (Grenze erreicht, Ordner nicht erreichbar) liefert Code mit Anlass und Text; Spannung zu „Datenbank nie sichtbar“ (HANDOFF §8, Punkt 9) entscheidet Johannes.

## L-E Zustände ohne Entwurf (MAIL-L06)
- Liste offline (Tweak mail „offline“, `:648`): Liste bleibt, Hinweis kind warning „Keine Verbindung“ / „Die zuletzt geladenen Mails bleiben lesbar.“ / „Erneut versuchen“ (`mail.notice.offline.*`).
- „Mehr laden“: Knopf, „Lädt …“, Fehler „Weitere Mails nicht geladen“ mit „Erneut versuchen“ (schon gezeichnet, Tweak failure „Nachladen“). Ob per Knopf oder beim Scrollen kommt, entscheidet Code (N7).
- Konto nicht erreichbar: schon gezeichnet (Tweak mail „nicht erreichbar“), Text „<Adresse> ist nicht erreichbar“.
- „Nicht gesendet · im Ordner Entwürfe“: siehe L13 b.

## Bereits offen aus v12
N4 (`mail.notice.mailTooLarge.*`, gezeichnet 21.10.), N7 (Fehler je Aktion: Tweak failure; Nachladen), N14 bis N17 (gezeichnet, N16 als Frage an Code), L-010 (Signatur je Postfach in der Konto-Karte): Stand unverändert, siehe `contract/LIEFERUNG.json`. **N2 neu (Brief 22.10.):** Abmelden-Zeile nennt Zahl und Namen der verbundenen Dienste, keine Warnung vor ungesendeten Mails (`ALFA Einstellungen.dc.html:288`).

## Nicht an Design, erst Johannes
Menüeinträge ohne Verhalten (Verschieben nach …, Notiz anfügen, Original anzeigen, Später senden …, Lesebestätigung anfordern, Als Vorlage sichern) und Formatleiste: **nichts gezeichnet, nichts geändert**; bleiben im Bogen wie vorher, bis er entschieden hat.

## Nicht geprüft
Bildschirm nicht von Design angesehen (Prüfer ausstehend); P4 nicht neu gelaufen (Hashes der zwei Bögen und Zeilen im Lieferschein nachgezogen); ZIP nicht erzeugt (Freigabe fehlt).
