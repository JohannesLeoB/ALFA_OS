---
name: brief-v10-entwurf
description: Entwurf Brief v10 an Design (L2-geprüft, N6 nach Johannes 20.10. „Mit, aber simpel“); wartet auf Freigabe zum Ablegen in DESIGN/brief/
metadata:
  type: project
---

Status 20.10.: Entwurf, nicht abgelegt. Johannes 20.10. zu N6: „Mit, aber simpel.“ und „Okay mit A - evtl einen „Schätzwert“ dazu? Aus Token Verbrauch und Preis / mio Token in out ?“. Wortlaut von v10 als Ganzes noch nicht freigegeben. Nach Freigabe: als DESIGN/brief/BRIEF.txt ablegen (ersetzt v9), diese Datei löschen. Siehe [[design-brief-aktuell]].

```
Brief Code → Design · v10 · 20.10.2026

ZIEL
Unverändert aus v9: Der nächste Export liefert für Mail, Einstellungen und Hülle (ALFA Shell) einen vollständigen Vertrag im Ordner contract/. Neu in v10: die Arbeitsweise (A1–A7) und sieben Nachlieferungen (N1–N7). T1 bis T8 aus v9 gelten weiter.

GRUNDLAGE
- Stand: Export "ALFA OS Interface CHEF 1610-handoff 1810.zip", 18.10.2026, sha256 d0ed5abb…3c8d2.
- Anhang wie v9. Maßgeblich ist immer die Fassung in diesem Ordner auf GitHub (JohannesLeoB/ALFA_OS, DESIGN/brief/).

ARBEITSWEISE
A1 Eine Quelle. Jeder Wert, den eine Ansicht zeigt (Maß, Farbe, Schrift, Laufweite, Deckkraft, Dauer, Kurve, Grenze, Zahl), steht als Token im Vertrag. Die Bögen verweisen nur per var(--…) darauf. Eine Zahl, die nur inline im Bogen steht, gilt als nicht geliefert. Beispiele, die heute nur inline stehen: ALFA Mail.dc.html:74 height:96px, :59 letter-spacing .01em.
A2 Ein Format. TOKENBOGEN.json entfällt oder wird aus contract/ erzeugt; zwei Wertquellen nebeneinander gibt es nicht.
A3 Ort. contract/ liegt im Export auf oberster Ebene neben project/.
A4 Pflichtdateien. base.tokens.json, theme-light.tokens.json, theme-dark.tokens.json, alfa.resolver.json, components.json, views.json, texts.json, changes.json, dazu akte.json und werte-abgleich.json aus T7. Fehlt eine oder ist sie leer, ist der Export nicht geliefert.
A5 Prüfen vor dem Export. P1 und P2 laufen ohne Fund, P3 ab dem zweiten Vertrag (wie T8), bevor die ZIP entsteht; ihre Ausgaben liegen dem Export als contract/PRUEFUNG.txt bei.
A6 Verhalten. Zu jedem Bauteil mit Zuständen oder Bewegung: Zustände, Übergänge, Grenzbreiten und Umbruch als Angaben in components.json. Was nicht angegeben ist, baut Code ohne Übergang.
A7 Entscheidungen von Johannes gehen vor. Sie stehen in diesem Brief mit Datum; der Vertrag übernimmt sie wörtlich.

ANNAHME BEI CODE
Code prüft jeden Export mit denselben Skripten und sucht zusätzlich lose Zahlen in den Bögen. Ein Fund heißt: nicht angenommen, nichts gebaut, Rückgabe als Liste an dich.

NACHLIEFERUNGEN (zeichnen und in T2–T4 eintragen)
N1 DHL als eine Integration. Johannes 20.10.: „DHL Versand und Sendungsverfolgung sind EIN Integrations Item. keine zwei "stecker" sondern über dhl api readme und manual siehe apps von dhl dev.“ Heute zwei Karten: ALFA Dienste.dc.html:102 (dhl) und :103 (dhlversand), ebenso ALFA Mail.dc.html:399–400. Gesucht: eine Karte mit den Feldern für den DHL-Zugang.
N2 Abmelden. ALFA Mail.dc.html:758 nennt sechs Dienste („Trennt Google, Clockodo, ClickUp, sevDesk, Airtable und Claude …“), INHALT.json:403 „alle Dienste“; es gibt zehn. Festlegen, was Abmelden trennt, und den Text danach.
N3 Laufweite. Kein Token für letter-spacing; inline stehen .01em, .02em, .04em, .06em, .08em, -.02em, -.035em (ALFA Mail.dc.html, ALFA Shell.dc.html:47, ALFA Dienste.dc.html:18, :28, ALFA Huelle.dc.html:17); tracking-display -0.01em nur als Vorschlag (design-system/alfa-ds-tokens.js:80). Je Textstil ein Laufweite-Token.
N4 Mail zu groß. Gezeichnet sind nur „Nicht gesendet / Der Server hat nicht geantwortet“ (ALFA Mail.dc.html:1002) und „Senden braucht die Schreibfreigabe“ (:1003). Hinweis und Text, wenn eine Mail die Größengrenze des Anbieters überschreitet.
N5 Sofort-Abgleich. Das Takt-Menü (ALFA Mail.dc.html:744) hat Aus, Manuell und sechs Zeitabstände. Code kann bei IMAP-Konten neue Mail sofort melden (IDLE). Eintrag und Text dafür, oder die Angabe, dass er nicht sichtbar wird.

N6 KI-Integrationen (Claude und folgende): Modellwahl aus der Modellliste des Anbieters. Zähler „Tokens seit <Datum>, <n> Tage“ (Eingabe und Ausgabe), kumuliert ohne Einzeleinträge, mit Zurücksetzen und Bestätigung. Dazu ein Schätzwert „ca. <Betrag>“ aus Tokens × Preis je Mio. Tokens (Eingabe und Ausgabe); den Preis je Modell trägt der Nutzer in der Detailkarte ein, ohne Preis kein Schätzwert. Kein Guthaben (beim Anbieter nicht abrufbar).

N7 Fehler und Nachladen in Mail. Gezeichnet sind Fehler nur für Liste (ALFA Mail.dc.html:868), Verbindung (:874), Senden (:935, :1000–1002) und Abgleich (:1077); 33 toastIt-Aufrufe (:530–1086) ohne Fehlertext. Für Archivieren, Verschieben, Papierkorb, Markieren, Lesen, Anhang, Verlauf, Entwurf speichern und einen lokal nicht gespeicherten Postausgang fehlt eine Darstellung samt Text. Nachladen: Der Knopf „Mehr laden“ ist gezeichnet (:121), aber nie aktiv (:844 hasMore: false; loadMore und moreText nicht definiert); das Fenster wächst nur über geladene Zeilen (:877–878). Festlegen: Fehlerdarstellung je Aktion; ob weitere Mails vom Server per Knopf oder beim Scrollen kommen, mit Text.

ERINNERUNG AUS v9
- Kachelhöhe Integrationen 112 (Johannes 19.10.); der Export hat 96 (ALFA Mail.dc.html:74, TOKENBOGEN.json:2587). Im Vertrag 112.
- W-05 Dienstzahl und L-010 Signaturen je Postfach sind weiter offen.

ABGABE
Je Schritt T1 bis T8 und N1 bis N7 „erledigt“ oder „offen“, dazu contract/PRUEFUNG.txt.
```
