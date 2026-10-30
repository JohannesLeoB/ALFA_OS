# Aufträge an Design – Nachtrag 30.10. (von Johannes am 30.10. freigegeben)

Grundlage: Master 28.10. Vorbild: die Class Leaders Apple Mail (macOS 27) und Gmail. Belege sind selbst gelesen am 30.10. Was der Server kann, wurde live bei den Servern abgefragt.

## D1 Konto anlegen nur mit Adresse
- **Ist (Bogen 28.10., ALFA Einstellungen.dc.html, accountBlocks):** Ein Formular mit Anbieter-Menü (Gmail/GMX/IONOS), Anzeigename, Server Eingang, Port, Verschlüsselung, Server Ausgang, Passwort und Passwort Ausgang. Ein Feld für die E-Mail-Adresse fehlt.
- **Vorbild Apple Mail** („Account hinzufügen“, Handbuch mail35803):
  - Zuerst nur „E-Mail-Adresse eingeben“ und „Fortfahren“, oder „Anbieter wählen“ (iCloud, Microsoft Exchange, Google, Yahoo, AOL, „Anderen Account hinzufügen …“).
  - Danach erscheinen Name, E-Mail-Adresse und Passwort, mit den Knöpfen Abbrechen, Zurück und Anmelden.
  - Server fragt Apple nur ab, wenn sie nicht gefunden werden.
- **Code kann schon:** Seit Commit 68d98a6 findet ALFA die Server aus der Adresse, für jeden Anbieter: Konfiguration des Anbieters, DNS-Einträge nach RFC 6186, Thunderbird-Verzeichnis, MX-Eintrag.
- **Gebraucht:**
  - Ein Schritt nur mit Adresse.
  - Ein Zustand „Server werden gesucht“.
  - Ein Zustand „Keine Server gefunden, bitte eintragen“, der die Serverfelder aufklappt.
  - Ein Feld für die Adresse.

## D2 Abbestellen
- **Vorbild:**
  - Apple Mail (mlhlp1065): Banner unter dem Kopf der Mail „Diese E-Mail stammt von einer Mailingliste“, Knopf „Abmelden“, danach ein Warnhinweis mit OK. Nach der Abmeldung verschwindet das Banner.
  - Gmail (15433283): „Abbestellen“ neben dem Absendernamen, Pop-up mit „Abbestellen“ oder „Website aufrufen“.
- **Technik:**
  - Läuft bei jedem Anbieter über die Kopfzeile `List-Unsubscribe` (RFC 2369).
  - Ein Klick reicht nach RFC 8058 (`List-Unsubscribe-Post`).
  - Ohne One-Click gibt es nur eine Webadresse; dann braucht es „Website aufrufen“.
- **Gebraucht:**
  - Ein Banner oder ein Knopf in der Mailkarte.
  - Eine Bestätigung.
  - Der Zustand „abgemeldet“.
  - Die Variante „Website aufrufen“.

## D3 Später senden
- **Ist:** Der Menüpunkt „Später senden …“ steht im Bogen (mail.menu.s024). Eine Zeitwahl und ein Ort für geplante Mails fehlen.
- **Vorbild:**
  - Apple Mail (mlhlp1098): Zeitvorschläge oder „Später senden“ mit Datum und Uhrzeit; Postfach „Später senden“; dort ändern über „Bearbeiten“ oder abbrechen.
  - Gmail (9214606): Ordner „Geplant“, bis zu 100 Mails.
- **Technik:**
  - Kein geprüfter Server plant den Versand.
  - Die Gmail-API hat keinen Zeitplan.
  - SMTP ohne FUTURERELEASE bei gmail, gmx, web.de, ionos, fastmail.
  - Der Versand geht also nur, solange ALFA läuft. Das muss die Ansicht ehrlich sagen.
- **Gebraucht:**
  - Eine Zeitwahl (Vorschläge und eigene Zeit).
  - Ein Ort „Später senden“ je Postfach, mit Ändern und Abbrechen.
  - Ein Hinweis, falls ALFA zum Zeitpunkt geschlossen war.

## D4 Wartezeit für Senden widerrufen (Einstellung)
- **Ist:** Seit Commit c15d876 hält ALFA die Mail so lange zurück, wie der Toast mit „Rückgängig“ zu sehen ist (Token toastUndo = 4 s).
- **Vorbild:**
  - Apple Mail: Einstellungen > Verfassen > „Verzögerung, um Senden zu widerrufen“ (aus, 10, 20, 30 s; Standard 10 s).
  - Gmail: 5, 10, 20 oder 30 s.
- **Gebraucht:** Eine Zeile in den Einstellungen, und die Dauer des Toasts muss sich dann nach dieser Zeit richten.

## D5 POP-Konto (gebaut 30.10., Ansicht bitte bestätigen)
- **Vorbild Apple Mail** (Handbuch mail14059, macOS 11): Accounts > Erweitert > „Nach Erhalt einer E-Mail Kopie vom Server löschen“, Einblendmenü. Die genaue Liste der Optionen habe ich nicht gelesen.
- **Gebaut mit vorhandenen Bausteinen:**
  - Im Kontoformular die Zeile „Kontoart“ (IMAP/POP), als Auswahl wie bei der Verschlüsselung. Die Erkennung setzt die Kontoart selbst.
  - In der Postfachkarte die Zeile „Kopie vom Server löschen“ mit Nie (Standard), Nach einem Tag, Nach einer Woche, Nach einem Monat, Beim Löschen in ALFA. Die Zeile erscheint nur bei POP.
  - Ein POP-Postfach zeigt Eingang, Entwürfe und Gesendet. Entwürfe und Gesendet liegen lokal, wie bei Apple „Auf meinem Mac“.
  - Archivieren, Verschieben und Spam fehlen dort, statt ausgegraut zu sein (N20).
- **Gebraucht von Design:** die Bestätigung beider Zeilen und ihrer Texte, und ob ein POP-Postfach im Deck einen Hinweis „lokal“ braucht.
