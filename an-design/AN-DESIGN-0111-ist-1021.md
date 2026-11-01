# Code → Design · Ist-Stand Build 1021 · 01.11.2026 (Auftrag von Johannes: „Augen über alles schweifen lassen“)

Grundlage: 43 Screenshots, die Johannes am 31.10. abends von Build 1021 gemacht hat (Dateinamen sagen „1020“, die App meldet 1021, gebaut aus `main` 0b441663). Drei Prüfer haben jedes Bild gelesen und gegen Master 2910 gelegt. Die Bilder selbst gibt Johannes der Design-Session als ZIP (`ALFA Ist 1021.zip`), weil sie echte Mails und Adressen Dritter zeigen und deshalb nicht in Git gehören. Bildnamen unten sind `screens 1020 bau<Zeit>.png`.

## 1 · Was die Bilder zeigen (Ablauf)
- **0.12–0.28 Einstellungen › Ich, Firma, Dateiordner.** Drei Bahnen: Kategorien, Mitte (Profilkarte schwarz mit JB, Kürzel, Telefon, Adressen; darunter „Darstellung · Hell“), rechts die Detailkarte (Name, Rolle, Kürzel, Telefon, Geburtstag-Schalter, Block „Konto“ mit „Auf diesem Mac abmelden“ und „Nutzerkonto stilllegen“).
- **0.33–0.56 Mail.** Google: Ordner mit Entwürfe 113, Spam 2, vier Labels „MYKILOS/…“; Liste; rechts Entwurfsstapel. Stapelübersicht aufgefächert. Suche in schmaler Liste. Liste groß als Kacheln (6 Spalten, Hover-Aktionen). Label lädt. GMX: Eingang 554, Kacheln mit Ungelesen-Punkten, Ordner „OUTBOX“ (roher Serverordner), Lesekarte eines HTML-Newsletters.
- **1.01 Assistent** über Mail: drei „moin“, jeweils „Nicht beantwortet · Erneut versuchen“, Hinweis „Claude antwortet gerade nicht. In den Einstellungen neu verbinden.“ (kein Claude-Schlüssel eingetragen).
- **1.15 Blob mit Suche** „Finden“, Zeile „Mail 554“.
- **1.29–1.32 Schutz und System:** Datenschutz (inkl. „Freigaben für den Assistenten“), System (Version, Zweig, Datenbank, Diagnose), Impressum leer.
- **1.33–1.42 Verbindungen:** Kachelraster (Google, Mail-Konten verbunden; ClickUp, Clockodo, Claude, Airtable, sevDesk, DHL nicht verbunden; Gruppe Schlüssel mit „Schlüssel-Inventar“). Jede Dienstkarte einzeln geöffnet; Mail-Konten mit GMX; Schlüssel-Inventar; Google.
- **1.52–2.01 Google-Anmeldung im Browser:** Zustimmungsseite (noch „mykilOS“, kommt aus der Google Cloud), dann die Übergangsseite mit Blob „ALFA_OS“, erst ohne, dann mit Text „Google-Anmeldung übernommen · Dieses Fenster kann jetzt geschlossen werden.“
- **2.03–2.39 zurück in Einstellungen:** Google-Karte, Clockodo, Dateiordner › Ordnerschema und Vorlagen, Datei-Dialog bei „Anlegen“, Firma, Ich.
- **2.50 Dock:** zwei gleiche App-Icons laufen (zwei Builds gleichzeitig).

## 2 · Was Code daraus selbst behebt (läuft, ohne Frage an Design)
- Bahnen füllen das Fenster nach Rückkehr aus dem Browser nur zur Hälfte (2.03, 2.39) – Fenstergröße wird nicht nachgeführt.
- Lesekarte bei GMX bleibt blass wie unter einem Schleier (0.56, 1.05).
- Spam zeigt einen Zähler (Bogen zählt nur Eingang, Entwürfe, Postausgang).
- Ladetext ohne Fortschritt „12 von 50“ (0.47).
- Absender ohne Namen: mal Personensymbol, mal Buchstabe (0.43).
- Rechte Kanten der Detailkarte: Schalter enden 8 statt 16 pt vor dem Rand, Werte 20 statt 28 (fast alle Einstellungsbilder).
- Zeilen ohne Unterzeile behalten zweizeilige Höhe (1.29, 2.24); „Vorlagen“ ohne „Noch keine Vorlage“.
- Schlüssel-Inventar-Kachel: Monogramm zu klein, Innenmaß step8 statt step12, gewählte Kachel `ink` statt `inverse`.
- „10s“ statt „10 s“; Versionswerte in der Systemkarte zu groß.
- Datei-Dialog dunkel trotz „Fremde Inhalte · Immer hell“.
- Leere Signatur zeigt leeren Editor statt „Für dieses Postfach gibt es keine Signatur.“ + „Signatur anlegen“.
- Google-Abgleich zeigt nur „Mail“ (Bogen: Mail, Kontakte, Dateien, Drive-Ordner) – nur wo die App es wirklich abgleicht.
- Pillen in Zeilen wachsen nicht mehr aus der Karte, gekürzte Texte zeigen den vollen Wortlaut als Hilfe (Break-UI, `main` a3906be0).

## 3 · Fragen an Design (bitte beantworten oder im nächsten Master zeichnen)
**Aus den Screenshots**
1. **Schlüssel eintragen** (1.36–1.40, 2.20): Bei ClickUp, Clockodo, Claude, Airtable, sevDesk, DHL steht nur „Nicht eingetragen“, der einzige Weg ist das unbeschriftete Ketten-Symbol im Kartenkopf. Johannes hat jede Kachel geöffnet und den Weg nicht gefunden. Der Bogen zeichnet keine Eingabe. Bitte Eingabeweg zeichnen (Knopf in der Karte? Felder direkt editierbar?).
2. **Kartentitel**: Die rechte Detailkarte hat keinen Titel; nach einem Kategoriewechsel bleibt sie stehen (bogengetreu) und wirkt wie ein veralteter Rest (0.24, 1.33, 2.20). Titel oder Kategoriewechsel schließt die Karte?
3. **Suche in schmaler Liste** (0.36): „In allen (“ und „Übe…“ sind unlesbar. Was weicht bei Mindestbreite?
4. **Assistent ohne Schlüssel** (1.01): Eingabe bleibt aktiv, man sendet ins Leere; Text sagt „neu verbinden“, obwohl nie verbunden. Eigener Zustand mit „Einstellungen öffnen“?
5. **„OUTBOX“** (0.52): GMX bringt einen eigenen Serverordner „OUTBOX“ mit; er steht ohne Abschnittskopf mit Etikett-Symbol unter Papierkorb. Wie sollen fremde Serverordner aussehen (Kopf „Ordner“? eigenes Symbol)?
6. **Übergangsseite nach der Anmeldung** (1.57–2.01): eine Weile nur die Kapsel ohne Text; dunkel, App hell. Gehört zum Intro-Auftrag (`AN-DESIGN-3110-intro.md`).
7. **„Anlegen“ bei Vorlagen** (2.32) öffnet eine Dateiauswahl; der Bogen legt direkt „Vorlage n“ an. Wort oder Handlung?
8. **Vorlagen-Wert** im Ordnerschema zeigt einen gekürzten Dateinamen (2.24); der Bogen zeigt nur den Leerzustand.
9. **„Lokale Ablage“ bei Google** (1.42, 2.03): Der Bogen hat sie nur bei Mail-Konten; Code zeigt sie auch bei Google (Entscheidung 29.10.: jedes Postfach lädt einen Zeitraum). Bitte nachziehen.
10. **„Freigaben für den Assistenten“** (1.29): fünf Schalter unter Datenschutz ohne Bogen. Bitte zeichnen oder streichen.
11. **„Prüfen“ an der Postfachzeile** (1.35): ohne Bogen.
12. **Kürzel aus der Adresse** („BG“, „JM“, 0.33): bogengetreu (`ini2`), wirkt neben „JB“ fremd.
13. **„Secret“** bei DHL ist englisch (steht so im Master).
14. **Geburtstag-Schalter** ohne Geburtstagsfeld (0.12).
15. **App-Icon** im Master „Gesperrt · nicht abgenommen“ (2.50).
16. **Weißes Logo ohne Rand** im Dienstkopf (ClickUp, Google) wirkt neben farbigen Kacheln verloren (1.36).

**Aus der Break-UI-Prüfung (Worst-Case-Daten)**
- D1 Pille im Frage-Zustand bei mehrzeiligem Untertext (Stilllegen): Textspalte ausblenden, solange gefragt wird?
- D2 Warnung bei „Konto entfernen“ (POP-Mails nur lokal, ungesendete Mails) als Notice statt in der Frage?
- D3 Mail-Kopf im Auswahlmodus bei Mindestbreite: welche Knöpfe ins „Mehr“?
- D4 Notice-Knöpfe untereinander, wenn sie nicht nebeneinander passen?
- D5 Kürzel im 28-pt-Ring: Höchstlänge oder Skalierung?
- D6 Toast: einzeilig mit Kürzung in der Mitte oder zweizeilig?
- D7 Eingabe des Assistenten mehrzeilig bei langem Text?
- D8 Kontostapel: ab wie vielen Postfächern begrenzen oder scrollen?
- D9 Text für die Einzahl „Zitat zeigen · 1 Zeile“.
- D10 Zähler kappen, etwa „9.999+“?

**Bereits offen** (siehe `AN-DESIGN-3110-stand-2.md`, `-stand-3.md`): Absendername, „Sendet …“, Abmelde-Fehler, Felder von Hand, Bestätigen-Bogen, Bereich A, T1–T4, M1–M9, R1–R5, Intro-Bogen, Profil „Bild wählen“ und „Teams“, „Einrichtung · Erneut durchgehen“.

## 4 · Was Johannes klärt (kein Design)
- Claude-Schlüssel und die übrigen Dienstschlüssel eintragen; Rolle, Firmenname, Projektordner, Impressum.
- App-Name „mykilOS“ in der Google Cloud Console ändern.
- Nur eine App-Instanz laufen lassen (zwei gleichzeitig teilen sich die Datenbank).

## Nachtrag · Startfehler-Bildschirm (`main` d51331de)
Startet die App nicht, zeigt sie heute „Fehler · Domäne Code“ mit dem Fehlertext und den Knopf „Schließen“ (beendet die App). Bitte einen Bogen liefern: Titel, Wortlaut, ob es „Erneut versuchen“ gibt, und ob „Beenden“ statt „Schließen“.
