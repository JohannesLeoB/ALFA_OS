---
name: app-mail
description: "Funktionskarte Mail (Vertrag 155 Funktionen, Konten, Lücken): Ist, Soll, Offen, Stand 18.10."
metadata:
  node_type: memory
  type: project
  originSessionId: c2a04c8a-08ac-42dc-b4d2-3f9732b7dd70
  modified: 2026-10-18T16:57:43.173Z
---

Funktionskarte (Stand 18.10.; Ist = Bestand, Soll = sein Wort, Offen = belegte Frage)
Mail
- Ist: ALPHA-Gmail-Client in Nutzung; Vertrag `~/ALPHA/Design/BOGEN-MAIL.json` 3.1.0 „decided“, 155 Funktionen, 87 Aktionen; Stand 3.10.: 60 gebaut, 58 teilweise, 27 fehlen, 1 blockiert, 9 unklar (`~/ALPHA/ASSUMPTIONS.tsv:184`). ALFA_OS: `alfaos/App/Mail`, `Kit/Sources/Mail`, im Aufbau.
- Soll: „wie bei macOS mail eine allgemein gunktionierende "on board" mail funktion sicherstellen“ (02.10. 23:42 4effc045); „Nutzer sollen bis zu 3 Mailadressen/Konten angeben und nutzen können.“ (12.10. 14:43 a9bb817c); „Postfach/mail Accounts werden in den "EINSTELLUNGEN" gesetzt - also nicht in der "MAILANSICHT" direkt.“ (12.10. 18:48 7cc894d9).
- Offen: Klartext der 155 Funktionen (`MAIL-FUNKTIONEN-CODE.tsv`) liegt nicht in `~/ALPHA`; Texte „ohne Empfänger“ und „ohne Betreff“ fehlen (BOGEN-MAIL.json:1707–1713); Mehrfachauswahl und Rückgängig stehen nur in CHEF 1610, nicht im Vertrag.
- Gefunden 19.10. (Suche über alle Transkripte, ~/ALPHA, Master): Konten in der linken Bahn „Reiter nebeneinander, bei Platzmangel ein Menü (Empfohlen)“ (03.10. 15:48 ee8f053d); gemeinsame Postfächer info@/accounting@ „die auch alle User mitlesen und bedienen sollten“ (19.09. 18:38 labor 0db45317); Signatur „pro Postfach im Einstellungs Ansichtsbereich … anlegen, auswählen erstellen“ (13.10., Master entscheidungen.md:142), „IN den EINSTELLUNGEN „mailkonten“ signaturen anlegen, in Mails client nur „wählen““ (RUECKGABE-AN-CODE.md:54), Signatur mit Logo und Text je Konto (TEXTE-EINSTELLUNGEN.json:662-674, decided); Funktionsumfang wie macOS Mail/Gmail „mit den in APP specials wie anhang in projektordner, kontakt aus signatur, lead aus mail, Mail in Projektordner exportieren“ (17.09. 17:56 labor 0db45317); Drucken, PDF, In Drive sichern, Verschieben im Vertrag (BOGEN-MAIL.json:1075-1100); Bilder blockiert „pro Postfach in den Einstellungen on/off“ (07.10. 00:31 055e95fd); „Mail sollte eine lokale suche haben - ansonsten global im Head“ (20.09. 13:35 labor), „Suche Bleibt im BLOB“ (BOGEN-GLOBAL.json:1438). Offen: gemeinsamer Eingang oder getrennt; Labels Gmail oder eigene; Suche beim Anbieter oder lokal; Notiz intern, Später senden, Lesebestätigung, Als Vorlage (nur im Master gezeichnet).
