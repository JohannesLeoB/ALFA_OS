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
