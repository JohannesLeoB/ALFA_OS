# Entscheidungen Johannes an Code · 23.10.2026
Verbindlich. (Nicht im Lieferschein: delivery.schema.json kennt kein Feld für Entscheidungen.) Jede Zeile: Spec-ID · Regel · Fundstelle im Bogen · Herkunft (entscheidungen.md).

HUELLE-F10 · Blob-Punkt erscheint NUR, wenn der Assistent im verdeckten Zustand (Blob zu) auf einen Befehl geantwortet hat und die Antwort noch nicht gesehen ist. Er erlischt beim Öffnen des Assistenten. Kein Punkt für ungelesene Mail, Abgleichfehler oder Sonstiges. Gilt in allen Bereichen. · ALFA Shell.dc.html:70 (shell.notice), onMode(o, mode); ALFA Mail.dc.html, ALFA Einstellungen.dc.html (shDot) · Johannes 23.10. „BLOB-Punkt: NUR aktiviert, wenn …“; „das ist SPEC … an code als entscheidung“
HUELLE-F11 · Assistent kann sich im verdeckten Zustand auf der Vorderseite des Blobs (Blob in Ruhe) melden. Anzeige, Effekt und Verdrahtung werden später final festgelegt; bis dahin nur der Blob-Punkt (F10). Code legt nur den Anschluss an, keine eigene Anzeige. · ALFA Shell.dc.html:70 · Johannes 23.10. „definieren wir später. aber lege das als SPEC fest.“
HUELLE-H01 · Hilfetext an Griff und Blob erst nach 3000 ms Verweilen (motion.duration.hintDwell); Zeiger darf je 100 ms höchstens 7 px Luftlinie wandern (size.hintRadius), sonst beginnt das Verweilen neu. Klick, Taste, Scrollen blenden sofort aus; Tastaturfokus zeigt sofort. Kein natives Tooltip an diesen Stellen. Gilt in allen Bereichen. · ALFA Shell.dc.html (hintSetup, shell.hint) · Johannes 23.10.
MAIL-G01 · Bahngrenzen sind Sache des Bereichs, nicht der Hülle. Mail: linke Bahn beim Ziehen höchstens 280. Andere Bereiche ohne Grenze, bis Johannes je Bereich festlegt. · alfa-shell.js AREA.Mail.max · Johannes 22.10. (v14 Teil 2) und 23.10.
MAIL-P02 · Postfachkarten: Material 1:1 wie Karte rechter Stapel, voll gespiegelt (Glanzkante, Naht, Schatten, Radien unten). · ALFA Mail.dc.html:33, components.json account-card.measures.material · Johannes 23.10.
MAIL-P06 · Neue Mail geht immer vom Postfach der obersten Karte. · ALFA Mail.dc.html:35 · Johannes 23.10.
HUB-D04 / HUB-S01 · Untertitel und Werte in Kacheln nur, wenn sie aus der realen Anbindung kommen oder Kategorie bzw. Status sind; keine erfundenen Texte. · ALFA Einstellungen.dc.html:233–237 · Johannes 23.10.
FARBE-00 · Noch keine Farbwelten. Erst die Layouts in Code nachziehen. Farbbögen gesperrt. · Johannes 23.10.

Zu Brief v14 N40 (Shell:40, Shell:53 „Hilfetext entfernen“): ersetzt durch HUELLE-H01 — Johannes 23.10. nach v14: Hilfetext bleibt, erscheint erst nach Verweilen. Nicht entfernen.

Volle Spec-Liste mit allen IDs: SPEC-NACHTRAG-2310.md. Plan: PLAN-2310.md.
