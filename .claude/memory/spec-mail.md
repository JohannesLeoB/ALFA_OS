---
name: spec-mail
description: Mail: 59 Funktionen als Baum (was, wo, warum, Aussehen, Stand), Regeln, Lücken bei Design
metadata:
  type: project
---

# Mail · Spec

Eingetragen: 23.10.2026 · Verfasser: Claude (Sonnet 5.5, Lead-Bau) für Johannes Leo Berger · Stand gegen Code-Commit e9893b1 · Quelle im Code: alfaos/App/Mail, alfaos/Kit/Sources/Mail, alfaos/Kit/Sources/Hub/Providers/MailBinding.swift

Mail-Client für bis zu drei Postfächer (Gmail, IMAP). Stufe 1, fertig Ende November 2026.

F01 = MAIL-F01. AUSSEHEN: Zeile in `ALFA Mail.dc.html`. Dateien ohne Pfad: `alfaos/App/Mail/`, `alfaos/Kit/Sources/Mail/`; `App/` = `alfaos/App/`; `Hub/`, `ShellCore/` in `alfaos/Kit/Sources/`; IMAP = `fundus/alpha/Sources/AlfaServices/Mail/IMAPSMTPMailTransport.swift`. Brief v14.

## Regeln
- R01 Postfächer werden in Einstellungen und Hub verbunden, nie in Mail.
- R02 Höchstens drei Mail-Verbindungen je Person.
- R03 Senden nur auf Klick, nie doppelt; vor jeder Wiederholung Prüfung in Gesendet.
- R04 Mailinhalt, auch HTML, echt auf hellem Blatt.
- R05 Externe Bilder gesperrt bis zur Erlaubnis; kein JavaScript.
- R06 Endgültig löschen und Entwurf verwerfen nur mit Halten.
- R07 Suche „Überall“ ohne Spam und Papierkorb.
- R08 Tasten ruhen bei offenem Blob und beim Tippen.
- R09 Keine erklärenden Sätze in der Oberfläche.

## Liste
**F01 Ordnerleiste**  
WAS: Standardordner mit Zähler.  
WO: linke Bahn.  
WARUM: jeder Ordner mit einem Klick.  
AUSSEHEN: Mail:387, :831.  
STAND: teilweise; Entwürfe-Zähler nur dieser Sitzung (MailPresentation.swift:66-73).

**F02 Labels**  
WAS: eigene Ordner, Klick öffnet sie.  
WO: linke Bahn.  
WARUM: Mails je Kunde finden.  
AUSSEHEN: Mail:388, :833.  
STAND: gebaut, nicht abgenommen (MailFolderLane.swift:51-66).

**F03 Mailzeile**  
WAS: Absender, Betreff, Vorschau, Datum, Stern, Anhänge, Unterhaltung.  
WO: Liste.  
WARUM: Mail erkennen ohne Öffnen.  
AUSSEHEN: Mail:80-104.  
STAND: gebaut, nicht abgenommen (MailRowView.swift:43-174).

**F04 Nachladen**  
WAS: holt Mails über die ersten 50 hinaus.  
WO: Liste, Ende.  
WARUM: alte Vorgänge finden.  
AUSSEHEN: Mail:121; Zustand nicht gezeichnet (Brief N7).  
STAND: teilweise; Modell kann es (MailModel.swift:323-332), die Liste ruft es nie.

**F05 Filter**  
WAS: Alle, Ungelesen, Mit Anhang.  
WO: Liste, Kopf.  
WARUM: Offenes abarbeiten.  
AUSSEHEN: Mail:850-852.  
STAND: gebaut, nicht abgenommen (MailListLane.swift:55-96); nur geladene Mails.

**F07 Mehrfachauswahl**  
WAS: mehrere Mails lesen, archivieren, löschen, mit Rückgängig.  
WO: Liste, Kopf.  
WARUM: viel auf einmal aufräumen.  
AUSSEHEN: Mail:608-624, :855-863.  
STAND: gebaut, nicht abgenommen (MailModel+Selection.swift:32-78).

**F08 Schnellaktionen**  
WAS: bei Hover Markieren, Gelesen, Archiv, Papierkorb.  
WO: Liste, Zeile.  
WARUM: aufräumen ohne Öffnen.  
AUSSEHEN: Mail:887-890.  
STAND: gebaut, nicht abgenommen (MailRowView.swift:176-206).

**F09 Kontextmenü**  
WAS: Antworten, Weiterleiten, Archiv, Gelesen, Verschieben, Papierkorb.  
WO: Liste, Rechtsklick.  
WARUM: alles an einer Stelle.  
AUSSEHEN: Mail:525-536.  
STAND: teilweise; Verschieben ohne Wirkung (F43).

**F10 Zustände**  
WAS: lädt, leer, keine Treffer, Fehler, nicht verbunden.  
WO: Liste.  
WARUM: sehen, warum nichts da ist.  
AUSSEHEN: Mail:866-875; offline nicht gezeichnet (Brief N7).  
STAND: teilweise; offline ohne Anzeige (MailPresentation.swift:107).

## Suche
**F06 Suche**  
WAS: Tippen filtert, Enter fragt den Server.  
WO: Liste, Kopf.  
WARUM: Mail zu jedem Vorgang finden.  
AUSSEHEN: Mail:599-601, :846-847.  
STAND: teilweise; Server nur im gewählten Ordner (MailModel.swift:251).

## Lesen
**F11 Kopf und Empfänger**  
WAS: Absender, Adresse, Empfänger aufklappbar.  
WO: Lesekarte, Kopf.  
WARUM: sehen, wer beteiligt ist.  
AUSSEHEN: Mail:152-160.  
STAND: gebaut, nicht abgenommen (MailReadingView.swift:25-115).

**F12 Unterhaltung**  
WAS: alle Nachrichten mit Name, Datum, Text, Zitat.  
WO: Lesekarte.  
WARUM: ganzer Vorgang auf einen Blick.  
AUSSEHEN: Mail:161-198.  
STAND: gebaut, nicht abgenommen (MailReadingView.swift:128-258).

**F13 HTML-Mail**  
WAS: zeigt HTML mit eingebetteten Bildern.  
WO: Lesekarte.  
WARUM: Mail wie gesendet.  
AUSSEHEN: nicht gezeichnet (Brief N10).  
STAND: gebaut, nicht abgenommen (MailHTMLView.swift:64-175); ohne Sperrliste bleibt sie leer (:110-115).

**F14 Externe Bilder**  
WAS: Warnung mit Bilder laden; Einstellung dazu.  
WO: Lesekarte; Einstellungen › Datenschutz.  
WARUM: Schutz vor Zählpixeln.  
AUSSEHEN: Mail:164-169, :760; je Konto Brief N21.  
STAND: teilweise; ein Schalter (MailReadingView.swift:141-147), je Konto fehlt.

**F15 Gelesen beim Öffnen**  
WAS: Öffnen setzt gelesen.  
WO: Liste, Lesekarte.  
WARUM: Zähler zeigt Offenes.  
AUSSEHEN: Mail:648.  
STAND: gebaut, nicht abgenommen (MailModel+Reading.swift:33).

**F16 Kartenstapel**  
WAS: Klick zeigt Vorschau, Doppelklick behält; höchstens 6.  
WO: rechte Bahn.  
WARUM: mehrere Mails zugleich.  
AUSSEHEN: Mail:643-650.  
STAND: gebaut, nicht abgenommen (MailModel+Reading.swift:19-44).

**F17 Übersicht**  
WAS: Karten als Kacheln in drei Größen.  
WO: rechte Bahn.  
WARUM: schnell springen.  
AUSSEHEN: Mail:310-335, :952.  
STAND: gebaut, nicht abgenommen (MailOverviewView.swift:11-101).

**F18 Befehlskopf**  
WAS: Antworten, Allen antworten, Weiterleiten, Archiv, Papierkorb.  
WO: rechte Bahn, Kopf.  
WARUM: häufigste Handgriffe.  
AUSSEHEN: Mail:1029-1030.  
STAND: teilweise; zusätzlich Als Kontakt sichern (MailCommands.swift:42).

**F19 Fuß und Mehr-Menü**  
WAS: Drucken, PDF, Projektordner, Mehr.  
WO: Lesekarte, Fuß.  
WARUM: Ablage und Ausgabe.  
AUSSEHEN: Mail:1031-1033.  
STAND: teilweise; F43, F44 ohne Wirkung (MailMenus.swift:51-54).

## Aufräumen
**F39 Archivieren**  
WAS: ins Archiv, aus Menü mit Rückgängig; Taste E.  
WO: Kopf, Zeile, Menü.  
WARUM: Eingang leer, nichts verloren.  
AUSSEHEN: Mail:530, :889.  
STAND: gebaut, nicht abgenommen (MailModel+Actions.swift:50-90).

**F40 Papierkorb**  
WAS: Toast mit Rückgängig 4 s, sonst 1,8 s; Entf.  
WO: Kopf, Zeile, Menü.  
WARUM: Fehlgriffe zurücknehmen.  
AUSSEHEN: Mail:557, :559.  
STAND: gebaut, nicht abgenommen (ShellCore/DesignTokens.swift:177, :180).

**F41 Endgültig löschen**  
WAS: löscht im Papierkorb; nur angeboten, wenn der Server es kann.  
WO: Papierkorb, Zeile.  
WARUM: Speicher, Datenschutz.  
AUSSEHEN: Mail:558, :890.  
STAND: gebaut, nicht abgenommen; nur IMAP mit UIDPLUS (MailCore.swift:208-230, IMAP:320-322).

**F42 Markieren, Spam**  
WAS: Stern, gelesen, ungelesen, Spam melden.  
WO: Zeile, Mehr-Menü.  
WARUM: Wichtiges halten, Werbung los.  
AUSSEHEN: Mail:1031-1032.  
STAND: gebaut, nicht abgenommen (MailModel+Reading.swift:89-108).

**F43 Verschieben**  
WAS: Mail in gewählten Ordner.  
WO: Kontextmenü, Mehr-Menü.  
WARUM: Ablage je Kunde.  
AUSSEHEN: Mail:532; Verhalten nicht gezeichnet (Brief N20).  
STAND: Lücke; ohne Wirkung (MailActions.swift:29).

**F44 Notiz, Original**  
WAS: interne Notiz; Quelltext.  
WO: Mehr-Menü.  
WARUM: Wissen im Team; Herkunft prüfen.  
AUSSEHEN: Mail:1032; nicht gezeichnet (Brief N20).  
STAND: Lücke; ohne Wirkung (MailActions.swift:29).

**F45 Aktionsfehler**  
WAS: Scheitern einer Aktion wird sichtbar.  
WO: Liste, Lesekarte.  
WARUM: nichts geht still verloren.  
AUSSEHEN: nicht gezeichnet (Brief N7).  
STAND: Lücke; gemerkt (MailModel.swift:43), nirgends gezeigt.

## Verfassen
**F20 Neue Mail**  
WAS: ⌘N oder Knopf öffnet leere Karte.  
WO: linke Bahn.  
WARUM: sofort schreiben.  
AUSSEHEN: Mail:652-658.  
STAND: gebaut, nicht abgenommen (MailModel+Draft.swift:22-33).

**F21 Antworten**  
WAS: Karte mit Re: und Zitat, auch an alle.  
WO: Lesekarte, Kopf.  
WARUM: Vorgang bleibt eine Unterhaltung.  
AUSSEHEN: Mail:681-685.  
STAND: teilweise; Zitatkopf weicht ab (MailModel+Draft.swift:252-258).

**F22 Weiterleiten**  
WAS: Fwd:, Zitat, Anhänge hängen an.  
WO: Lesekarte, Kopf.  
WARUM: Vorgang weitergeben.  
AUSSEHEN: Mail:970.  
STAND: gebaut, nicht abgenommen (MailModel+Draft.swift:77-108).

**F23 Absender**  
WAS: Menü wählt das Postfach.  
WO: Entwurf, Von.  
WARUM: richtiges Postfach.  
AUSSEHEN: Mail:213-215.  
STAND: gebaut, nicht abgenommen (MailComposeView.swift:133-165).

**F24 Empfänger**  
WAS: An, Cc, Bcc als Chips mit Vorschlägen.  
WO: Entwurf.  
WARUM: richtige Adressen.  
AUSSEHEN: Mail:217-234.  
STAND: gebaut, nicht abgenommen (MailComposeView.swift:167-325).

**F25 Betreff und Text**  
WAS: Betreff, Text auf hellem Blatt.  
WO: Entwurf.  
WARUM: die Nachricht.  
AUSSEHEN: Mail:235-248.  
STAND: gebaut, nicht abgenommen (MailComposeView.swift:56-82); Klartext.

**F26 Formatleiste**  
WAS: Fett, Kursiv, Listen, Link.  
WO: Entwurf, Fuß.  
WARUM: gegliederte Angebote.  
AUSSEHEN: Mail:255-259; Wirkung nicht gezeichnet (Brief N20).  
STAND: Lücke; ohne Wirkung (MailComposeView.swift:103).

**F27 Datei anhängen**  
WAS: Dateien wählen, Chips mit Entfernen.  
WO: Entwurf, Fuß.  
WARUM: Pläne mitschicken.  
AUSSEHEN: Mail:249-253; Ziehen nicht gezeichnet (Brief N23).  
STAND: teilweise; Ziehen fehlt (MailStackLane.swift:75-88).

**F28 Aus Projektordner**  
WAS: Projekt › Ordner › Datei hängt an.  
WO: Entwurf, Fuß.  
WARUM: Unterlagen ohne Suchen.  
AUSSEHEN: Mail:998; nicht gezeichnet (Brief N15, N30).  
STAND: teilweise; Knopf aus, kein Dateiort (Setup/MailSetup.swift:78-83).

**F29 Signatur anwenden**  
WAS: Signatur des Postfachs unter jeder Mail.  
WO: Entwurf.  
WARUM: einheitlicher Auftritt.  
AUSSEHEN: Mail:243-247.  
STAND: fehlt.

**F30 Signatur anlegen**  
WAS: je Postfach anlegen und wählen.  
WO: Einstellungen › Signatur.  
WARUM: wie F29.  
AUSSEHEN: Mail:759; Anlegen nicht gezeichnet (Brief L-010).  
STAND: Lücke.

**F31 Entwurf sichern**  
WAS: ⌘S sichert beim Anbieter; Kopf zeigt den Zustand.  
WO: Entwurf.  
WARUM: nichts geht verloren.  
AUSSEHEN: Mail:626, :1000.  
STAND: gebaut, nicht abgenommen (MailModel+Draft.swift:125-150).

**F32 Sichern beim Schließen**  
WAS: Schließen mit Inhalt sichert.  
WO: Entwurf.  
WARUM: kein Text geht verloren.  
AUSSEHEN: Mail:660-669; Scheitern nicht gezeichnet (Brief N19).  
STAND: teilweise; Scheitern unsichtbar (MailModel+Draft.swift:142-146).

**F33 Entwurf öffnen**  
WAS: Zeile in Entwürfe öffnet ihn.  
WO: Entwürfe.  
WARUM: Angefangenes beenden.  
AUSSEHEN: Mail:651.  
STAND: gebaut, nicht abgenommen (MailModel+Draft.swift:167-185).

**F34 Entwurf verwerfen**  
WAS: löscht nach Halten, auch beim Anbieter.  
WO: Entwurf, Kopf.  
WARUM: Ordnung.  
AUSSEHEN: Mail:671, :1035.  
STAND: gebaut, nicht abgenommen (MailModel+Draft.swift:152-165).

**F35 Mehr-Menü Entwurf**  
WAS: Später senden, Lesebestätigung, Vorlage, Drucken.  
WO: Entwurf, Mehr.  
WARUM: Versand planen, Vorlagen.  
AUSSEHEN: Mail:1040; nicht gezeichnet (Brief N20).  
STAND: Lücke; ohne Wirkung (MailStackLane.swift:57-71).

**F36 Senden**  
WAS: ⌘Enter oder Knopf; aus ohne Empfänger oder Betreff.  
WO: Entwurf, Fuß.  
WARUM: Mail kommt an.  
AUSSEHEN: Mail:672-680.  
STAND: gebaut, nicht abgenommen (MailModel+Draft.swift:187-223).

## Postausgang
**F37 Postausgang**  
WAS: ohne Netz wartet die Mail bis zum Abgleich.  
WO: Hintergrund.  
WARUM: nichts verloren, nichts doppelt.  
AUSSEHEN: Mail:874; Ansicht nicht gezeichnet (Brief N7).  
STAND: teilweise; keine Ansicht (MailCore.swift:312-447), IMAP-Versand legt keine Kopie in Gesendet ab (IMAP:119-132); bei Gmail legt Google sie selbst ab, bei anderen IMAP-Anbietern entscheidet der Server, ungeprüft.

**F38 Sendehinweise**  
WAS: Nicht gesendet; fehlende Schreibfreigabe.  
WO: Entwurf, oben.  
WARUM: Nutzer weiß, was tun.  
AUSSEHEN: Mail:1002-1003; zu große Mail Brief N4.  
STAND: gebaut, nicht abgenommen (MailComposeView.swift:20-32).

## Anhänge
**F46 Sichern unter**  
WAS: speichert den Anhang.  
WO: Lesekarte, Anhang.  
WARUM: Unterlagen weiterverwenden.  
AUSSEHEN: Mail:697-701.  
STAND: gebaut, nicht abgenommen (MailActions.swift:61-68).

**F47 Vorschau**  
WAS: zeigt den Anhang.  
WO: Anhang-Menü.  
WARUM: schnell prüfen.  
AUSSEHEN: Mail:698; nicht gezeichnet (Brief N23).  
STAND: Lücke; ohne Wirkung (MailActions.swift:69).

**F48 In anderes Projekt**  
WAS: Anhang in gewählten Projektordner.  
WO: Anhang-Menü.  
WARUM: Unterlagen in die Akte.  
AUSSEHEN: Mail:699; nicht gezeichnet (Brief N17).  
STAND: Lücke; ohne Empfänger (MailModel+Reading.swift:138-142).

## Drucken, PDF, Projektordner
**F49 Drucken**  
WAS: ⌘P öffnet den Druckdialog.  
WO: Lesekarte, Fuß.  
WARUM: Mail auf Papier.  
AUSSEHEN: Mail:1033; Seite nicht gezeichnet (Brief N16).  
STAND: gebaut, nicht abgenommen (MailPrinting.swift:13-26).

**F50 Als PDF**  
WAS: speichert die Mail als PDF.  
WO: Lesekarte, Fuß.  
WARUM: ablegen, weitergeben.  
AUSSEHEN: Mail:1033; Seite nicht gezeichnet (Brief N16).  
STAND: gebaut, nicht abgenommen (MailPrinting.swift:28-41).

**F51 In Projektordner**  
WAS: Mail als PDF in den Projektordner.  
WO: Lesekarte, Fuß.  
WARUM: Anfrage gehört zum Projekt.  
AUSSEHEN: Mail:1033; nicht gezeichnet (Brief N16, N30).  
STAND: teilweise; Knopf aus ohne Dateiort (MailCommands.swift:53).

## Kontakte
**F52 Personenmenü**  
WAS: Adresse kopieren, Mail schreiben, Kontakt sichern.  
WO: Lesekarte, Namen.  
WARUM: Adressen ohne Abtippen.  
AUSSEHEN: Mail:694-696.  
STAND: gebaut, nicht abgenommen (MailActions.swift:34-56).

**F53 Kontakte pflegen**  
WAS: sichern, bearbeiten, entfernen, anlegen.  
WO: Einstellungen › Kontakte.  
WARUM: Kundenadressen an einer Stelle.  
AUSSEHEN: Mail:752-757.  
STAND: gebaut, nicht abgenommen (App/Settings/SettingsSectionCards.swift:257-307); nur dieses Gerät.

**F54 Kontakte aus Diensten**  
WAS: Kontakte aus Google, iCloud, Karteien.  
WO: Einstellungen › Hub.  
WARUM: eine Adressquelle.  
AUSSEHEN: nicht gezeichnet (Brief N33).  
STAND: Lücke.

## Konten
**F59 Mehrere Postfächer**  
WAS: bis zu drei, je Postfach Ordner und Zähler.  
WO: linke Bahn.  
WARUM: alle Postfächer in einer App.  
AUSSEHEN: Mail:830; Wähler nicht gezeichnet (Brief N22).  
STAND: teilweise; einfache Liste (MailAccountPicker.swift:10-26).

## Abgleich
**F56 Abgleich**  
WAS: alle 5 Minuten, beim Start, von Hand.  
WO: Hülle › Sync-Knopf.  
WARUM: Eingang aktuell.  
AUSSEHEN: Mail:1077; Sofort nicht gezeichnet (Brief N5).  
STAND: gebaut, nicht abgenommen (App/Host/AppHost.swift:55-61).

**F57 Sofortmeldung IMAP**  
WAS: neue IMAP-Mail löst sofort Abgleich aus.  
WO: Hintergrund.  
WARUM: Anfragen ohne Wartezeit.  
AUSSEHEN: nicht gezeichnet (Brief N5).  
STAND: gebaut, nicht abgenommen (IMAP:341-352).

**F58 Ungelesen-Zähler**  
WAS: Zahl am Eingang und Blob; Punkt bei Neuem.  
WO: linke Bahn; Hülle › Blob.  
WARUM: Neues fällt auf.  
AUSSEHEN: Mail:831, :1074.  
STAND: gebaut, nicht abgenommen (App/Shell/BlobView.swift:86).

## Tasten
**F55 Tastenkürzel**  
WAS: ⌘N, ⌘R, ⌘⇧R, ⌘⇧F, ⌘S, ⌘Enter, ⌘P, E, Entf.  
WO: ganz Mail.  
WARUM: schnell arbeiten.  
AUSSEHEN: Mail:627-641.  
STAND: gebaut, nicht abgenommen (MailKit.swift:32-41).

## Später
- Kalender in Mail: fehlt.
- Mail wird Lead oder Projekt: fehlt.
- Lokale Mailablage: Lücke (Brief N24).
- Microsoft 365: nicht in Stufe 1.
