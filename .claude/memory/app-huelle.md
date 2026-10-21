---
name: app-huelle
description: "Funktionskarte Hülle (Blob, Bahnen, Sync, Look, Fenster, Icon): Ist, Soll, Offen, Stand 21.10."
metadata:
  type: project
---

Funktionskarte (Stand 21.10.; Ist = Code, Soll = sein Wort, Offen = belegte Frage). Commits: `git log`.

Ist
- Hülle gebaut seit c2d585f (nach Master 1810), Bauteile f69af03 (`alfaos/App/Components`), Fenster-Minimum 896 breit mit Höhe nach Bildschirm-Seitenverhältnis 08d2ca3 (Johannes 19.10.). Code: `alfaos/App/Shell`, `alfaos/Kit/Sources/ShellCore`. Bogen-Zahlen ohne Token: `ShellCore/SheetValues.swift` (134 Zeilen ohne Fundstelle, siehe stand.md).
- Avatar-Kürzel: eigenes Kürzel, sonst Initialen nach Master-Regel (`ShellCore/Initials.swift`, 145e6f3); das Blob-Menü zählt nur Fehler wie der Master.
- Avatar-Regel „Kürzel gewinnt“ ist Johannes' Wort, nicht Master; der feste Eintrag „JB“ ist aus dem Katalog entfernt.
- App-Icon (Johannes 21.10.: „es gibt bereits icon entwürfe, diese gebe ich der design session.“): Übergangs-Icon „B A-Monogramm, vorläufig“ aus dem Master, 443b970; volles Quadrat ohne eigene Maske, Rundung im Dock von Johannes noch nicht geprüft.
- Nicht im Bild geprüft (die App startet nur Johannes).

Soll (Johannes' Wort)
- „Dockbar entfällt.“ (03.10. 20:42 ee8f053d); Kopf „Ja, ganz weg (Empfohlen)“ (04.10. 00:56 ee8f053d); „Blob sitzt über den Spalten!!“ (10.10. 13:54 9740c1c5); „Und blob menu ist Hauptnavigatiom zwischen ansixhtsbwreixhen“ (10.10. 22:45 7cc894d9); „Seitenbahnen folden ab 112, 280 ruhemass, mittelbahn ebenso.“ (16.10. 14:39 97326b1d); „Die App ist auf Fullscreen ausgelegt.“ (17.10. 22:10 c2a04c8a); „DIE bedienung soll hauptsächlick aus MAUS nicht auf Tastenkombis angelegt sein.“ (09.10. 09:06 7ac4d629); Sync „klein, wie der BLOB evtl aber fest und rechts oben?“ (04.10. 19:36 ee8f053d); „3 Sekunden PRESS aus den BLOB Button“ (04.10. 17:53 ee8f053d); „Weiß, Haarlinien“ (10.10. 22:58 7cc894d9); „Nur das ALFA-Interface, keine Farbwelten“ (10.10. 02:33 9740c1c5); „"Stein" und "stahl" und sowas soll nicht im code sein bitte, nicht in token etc“ (10.10. 23:04 7cc894d9).
- Schrift: Johannes 18.10. im Design-Projekt „600 übrnehmen.“ (Schnitt semibold). Fokusring-Abstand (19.10.): „Design entscheidet“.

Offen
- Blob-Bedienung (Klick, Doppelklick, Langdruck): BOGEN-GLOBAL und Entwurf „Mail dicht“ waren verschieden; gegen Master 1810 nicht neu geprüft.
- Mindestfenster: das Interface 11.10. nannte 960×600; überholt durch 896 breit (Johannes 19.10.).
- Artifact „ALFA Farbwelten“ (16.10.) und Kanon-Paletten steel/dusk/ember/horizon stehen gegen sein Wort „keine Farbwelten“; nur Herkunft.
