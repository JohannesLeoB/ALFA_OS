# Code → Design · Auftrag ALFA_OS-Intro · 31.10.2026 (Auftrag von Johannes)

**Rolle:** Creative Director für die Marke ALFA_OS. Grundlage ist das UI-Pack des gültigen Masters (MASTER-2910, `ALFA UI-Elemente.dc.html`) mit Icon, Blob, Schrift, Farben und Bewegung der Shell. Nichts Neues erfinden, das nicht aus dieser Welt kommt.

## Welcher Master gilt und wo er liegt
- Es gilt immer der **neueste** Master. Welcher das ist, steht in `DESIGN/MANIFEST.json` auf dem Branch `main` von GitHub `JohannesLeoB/ALFA_OS` (Eintrag `"rank": "latest"`). Heute ist das `DESIGN/ALFA Design Master 2026-10-31.zip` (geliefert als „ALFA OS Interface CHEF 2810“, Ordner MASTER-2910). Der vorige (`2026-10-28`) gilt nicht mehr.
- Johannes gibt dir den Master als ZIP im Chat; das ist dieselbe Datei. Nichts aus anderen Ordnern, Branches oder Tags verwenden.
- Kommt während der Arbeit ein neuerer Master, gilt ab dann dieser.

## Seh- und Lesematerial im Master (Ordner `project/`)
- `ALFA Icon.dc.html` und `material/icons/`: das ALFA_OS-Icon und die Glyphen.
- `ALFA Shell.dc.html` und `alfa-shell.js`: der Blob (Ruhezustand, Flug, Breite, Einzug) und die Bewegung der Shell; dazu der Sperrbildschirm mit dem Zeichen.
- `ALFA UI-Elemente.dc.html`, `ALFA Designsystem.dc.html`, `alfa-theme.css`: Bausteine, Schrift, Farben hell und dunkel.
- `ALFA Tokenbogen.dc.html`, `TOKENBOGEN.json` und `contract/*.tokens.json`: Dauern, Kurven, Farben, Maße; `contract/texts.json`: Textschlüssel.
- `entscheidungen.md`: frühere Entscheidungen von Johannes.

## Bilder vom heutigen Stand
Johannes legt sie dir in den Chat: die heutige Seite nach der Anmeldung (grauer Grund, eine Textzeile) und die Zustimmungsseite von Google, auf der noch „mykilOS“ steht.

## Wo es läuft
Nach einer erfolgreichen Anmeldung bei Google oder Microsoft öffnet ALFA_OS eine Seite im Browser. Heute steht dort nur „ALFA_OS · Google-Anmeldung übernommen“ auf grauem Grund. Diese Seite wird zum **Studio-Intro von ALFA_OS**: der Moment wie das Start-„DONG“ eines Mac oder das Studio-Logo vor einem Film.

## Auftrag
1. **Markenbotschaft:** Was sagt ALFA_OS in einem Satz oder einem Bild? Entwirf die Botschaft, die das Intro trägt (deutsch und englisch).
2. **Sequenz:** 2 bis 5 Sekunden. Ein Storyboard mit Zeitachse: was erscheint wann, wie bewegt sich Icon und Blob, wie endet es. Endbild: ALFA_OS-Zeichen, die Zeile „Anmeldung bei {Anbieter} übernommen“ und der Hinweis, dass das Fenster geschlossen werden kann.
3. **Ton (optional):** ob ein kurzer Klang dazugehört und wie er klingt. Browser spielen Ton oft nur nach einem Klick; das Intro muss ohne Ton genauso tragen.
4. **Ruhige Bewegung:** Bei „Bewegung reduzieren“ zeigt die Seite sofort das Endbild.

## Lieferung
- Ein Bogen `ALFA Intro.dc.html` im Master: eine eigenständige HTML-Seite (CSS, JS und SVG inline, keine Anfragen ins Netz, keine Webfonts von außen), die Sequenz abspielt.
- Zeiten und Kurven als Tokens (`duration.*`, Kurven) im Vertrag, Texte als Keys mit de und en.
- Hell und dunkel: Die Seite folgt der Systemeinstellung.
- Ein Platzhalter `{provider}` für Google oder Microsoft.

## Stand bei Code
Eine Code-Sitzung baut die Seite übergangsweise aus Teilen des Masters 2910 (Zeichen, Farben, Dauern) und benennt die App überall einheitlich ALFA_OS. Sobald der Bogen da ist, ersetzt Code die Seite 1:1 danach. Der Name „mykilOS“ auf Googles Zustimmungsseite kommt aus der Google Cloud Console und wird dort von Johannes geändert.

## Nachtrag · Übergangsseite gebaut (`main` 630e2103)
- Die Seite nach der Anmeldung zeigt jetzt den Blob als Zeichen: Er erscheint, wird breit mit „ALFA_OS“, blinzelt einmal, darunter Titel und Zeile. Alle Farben, Maße, Dauern und Kurven kommen aus den Tokens des Masters 2910.
- **Ohne Token erfunden** (bitte durch den Bogen ersetzen): Verzögerungen 200, 900, 980, 1060, 1700, 1900 und 2100 ms; Breite des Schriftzugs 96px; Startgröße 0,92; Blinzeln auf 0,12; ein leiser Zweiklang (392 und 587,33 Hz, Lautstärke 0,05), der nur spielt, wenn der Browser Ton ohne Klick erlaubt.
- **Abweichung vom Master auf Johannes' Wunsch:** Die App heißt überall „ALFA_OS“. Damit weichen `mail.later.missed`, `mail.later.notice.title` und `mail.later.notice.text` vom Master ab (dort „ALFA“). Bitte im nächsten Master übernehmen.

## Nachtrag 2 · Blob als Rückweg in die App (`main` ddedc20e)
- Ein Klick auf den Blob der Seite holt ALFA_OS nach vorn (Link `alfaos://open`); die Seite versucht danach nach 0,6 s den Tab zu schließen.
- **Ohne Bogen erfunden:** Der Blob hat im Master keinen Knopf-Zustand. Hover und Fokus nutzen übergangsweise `opacity.ringOnMark` als Füllung des Gesichts und `size.selectionRingWidth` als Fokusring. Bitte im Intro-Bogen Hover, Fokus und Druck des Blobs festlegen.

## Nachtrag · Drop-in für Grok Imagine (Johannes, 31.10. 23:20)
- Johannes gestaltet die Intro-Sequenz zusätzlich mit Grok Imagine als Motion Designer. Dafür liegt hier ein Drop-in: `AN-DESIGN-3110-intro-grok-imagine/` (entpackt) und `AN-DESIGN-3110-intro-grok-imagine.zip` (zum Hochladen).
- Inhalt: `BRIEF.txt` (Rolle, Markenbausteine Blob, Orb, Icon, Geist, Farben, Bewegungssprache; was feststeht, was offen ist, Lieferung in drei Runden), `tokens/` (Kontrakt 2910, App-Tokens, Werte der Seite), `master/` (Shell, Theme, Tokenbogen, Icons mit App-Icon-Ebenen), `designsystem/`, `app-icon/`, `fonts/` (Geist), `ist/` (die heutige Seite lauffähig, Safari-Aufnahmen, Standbilder, Spezifikation mit Zeitplan).
- Stand der Seite in `ist/`: `main` 3ce69713 (Blob nach Master: Ring als Hairline, Lider, Blinzeln, Augen folgen der Maus, Geist eingebettet, Klick öffnet die App über `alfaos://open`).
- Was Grok liefert, geht als Material an Design; der Bogen `ALFA Intro.dc.html` bleibt Designs Lieferung.
