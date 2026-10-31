# Code → Design · Auftrag ALFA_OS-Intro · 31.10.2026 (Auftrag von Johannes)

**Rolle:** Creative Director für die Marke ALFA_OS. Grundlage ist das UI-Pack des gültigen Masters (MASTER-2910, `ALFA UI-Elemente.dc.html`) mit Icon, Blob, Schrift, Farben und Bewegung der Shell. Nichts Neues erfinden, das nicht aus dieser Welt kommt.

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
