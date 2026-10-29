# Abgleich Einstellungen · Mail gegen Einstellungen Inhalt · Durchgang 1 · 15.10.2026

Status: Vorschlag, nichts abgenommen. Zeilen aus dem Lesestand dieser Runde.
I = `ALFA Einstellungen Inhalt.dc.html`, M = `ALFA Mail.dc.html`.

## Korrektur der ersten Fassung
- „mailkonten“ ist kein Abschnitt in `SET`. Es ist ein Dienst in `SVC` (M 391).
- „Nur in Mail“ war falsch. signatur, start, sperre, kuerzel, einrichtung, diagnose, backups, tagebuch, werkstatt haben Gegenstücke in I (Tabelle unten).
- Echt nur in Mail: **kontakte** (M 733, `B.kontakte`) und die Zeile „Kürzel“ in `profil`.

## Quellen
- I: `SECT` 190–196 (5 Gruppen, 12 Abschnitte), `FN` 197–208, `SVC` 209–219 (9 Dienste).
- M: `SET` 401–407 (15 Abschnitte), `CATSET` 408 (Person, Ansicht, System; Integrationen kommt aus `SVC` M 389–), Karteninhalte `B` 732–752.

## Abschnitt für Abschnitt
| Mail (M) | Inhalt (I) | Nur in Mail | Nur in Inhalt |
|---|---|---|---|
| profil | identitaet | Zeile Kürzel | Abteilung, Kurzbeschreibung, Clockodo-ID, Team-Verzeichnis |
| signatur | mail › signatur | Schalter „Unter neue Mails setzen“ | Postfach- und Signaturwahl, Vorschau, Neue Signatur, Bearbeiten |
| kontakte | – | ganzer Abschnitt | – |
| datenschutz | datenschutz | – | Freigabe je Kategorie |
| darstellung | darstellung › erscheinung; mail › html, schrift | – | Größe |
| start | darstellung › start | – | – |
| sperre | darstellung › sperre | – | – |
| mitteilungen | mail › neue | Hinweistext | – |
| kuerzel | darstellung › kuerzel | Liste der 13 Kürzel | – |
| einrichtung | ordner › einrichtung, system › einr2 | Zeilen Projektordner, Projektdaten, Vorlagen | Fortschrittsbalken 57 % |
| diagnose | system › diagnose | Zweig, Datenbank | – |
| backups | system › backups | Liste der drei Sicherungen | „Ordner“ |
| tagebuch | system › tagebuch | Fehlerkarte | – |
| werkstatt | system › werkstatt | die drei Werte | – |
| schluessel | schluessel | – | – |
| Dienste | integrationen | Gruppe Persönlich/Firma je Dienst | – |
| – | firma, ordner (5 weitere), vorlagen, konten (Konto hinzufügen), mail › abruf, impressum | – | alle |

## Widersprüche · Antworten von Johannes (15.10.)
1. Tastenkürzel 12 / 13: „Das sind ja EH alles Dummy-Daten, nicht realer Code, also EGAL!“ → gestrichen.
2. Version: Antwort „Was bitte?“ → Frage unklar, gestrichen (Dummy-Wert, siehe 1).
3. Schlüssel-Inventar 9: „Dummy Daten, kein realer Code!“ → gestrichen.
4. Mail-Konten: „Mail Konten und deren Darstellungs, Suboptionen, Optionen etc - das ist auch EINE Integration, Gmail nämlich, oder GMX, oder IONOS … der ‚mail und lesen/schreiben‘ Listeneintrag bei Einstellungen Inhalt rutscht also zu den ‚integrationen‘ und wird dort wie auch alle anderen ‚integrationen‘ verwaltet.“ → Ins Zielbild übernommen: Gruppe „Mail“ (I 192: konten, mail) entfällt, beide Inhalte wandern in Integrationen. Bilder-Schalter (I 204 `mail.bilder`, I 205 `datenschutz.mbilder`, beide id "bilder"), Antwort: „Integrationen. Mailkonto Integrations Einstellung.“ → Er gehört in die Einstellungen der Mail-Konto-Integration, einmal. Offen: ob Datenschutz (Mail 741 zeigt ihn dort auch) nur darauf verweist oder ihn ganz verliert.
5. Schrift: „dann klär das“. Beleg: Tokenbogen hat eine Familie, Stapel „Geist, SF Pro Text, system-ui“ (TOKENBOGEN.json 2532–2536). Mail liest `schrift` mit Vorgabe „Geist“ (M 767) und zeigt „Geist“ / „Systemschrift“ (M 742). Inhalt zeigt „Schrift System“ und „Größe 13“ unter Lesen und Schreiben (I 204). Johannes: „NEIN, es gibt KEINE feste Lesegröße“, Mails kommen als HTML und sind Fremdinhalte. → Keine Größe 13, keine Lesegröße-Einstellung. Offen bleibt nur, ob die App-Schrift „Geist / System“ als Schalter in Darstellung bleibt (Mail 742).

## Dienstzustand · Vorgabe von Johannes (15.10.)
„Kommt AUS der jeweiligen Integration und den vom jeweiligen USER in ‚Mitteilungen‘ gewählten jeweiligen Optionen und Setups.“
Ist-Stand im Code: `stOf` (I 238) nimmt den per Klick gesetzten Wert, sonst den festen Ausgangswert `st` des Dienstes (I 209–219). Er hängt weder an der Integration noch an Mitteilungen. Mail `mitteilungen` kennt heute nur „Neue Mail“ (M 745, Hinweis: übrige Regler „kehren mit ihren Bereichen zurück“). Der Zustand ist also Dummy, die Vorgabe noch nicht abgebildet.

## Zielbild (Vorschlag, nicht abgenommen)
Ein Bereich: linke Bahn 5 Gruppen aus I, kontakte der Gruppe Ich oder Mail zugeordnet (Entscheidung Johannes). Mittlere Bahn: Funktionen aus `FN` mit Dienstzustand. Rechte Bahn: Stapel und Übersicht aus Mail, Karten mit der Tiefe aus `FN`. Mail ruft den Bereich auf.

## Nicht geprüft
Render bei 1512 × 982, hell und dunkel. Dienstliste M gegen I (Anzahl, Gruppen). Dienstzustands-Logik `csOf` gegen `stOf`. Mail-interne Stellen, die `SET`/`B` außerhalb 732–752 und 870–1011 nutzen. Verifier-Lauf.

## Kontakte · Johannes (15.10.)
„Ist eine ‚Integration‘ wie z.b. Google Contacts, Apple Kontakte, oder Airtable oder … lokale eigene Datenbank mit Speicherort/Ordnerwahl.“ → Kein Abschnitt, sondern Integrationen. Eingetragen: Google (hatte „Kontakte“ schon als Abgleich), Apple Kontakte, Lokale Kontakte (Ordnerwahl), Airtable (vorhanden). Mails Abschnitt „kontakte“ (M 733) entfällt als eigener Abschnitt. Die Liste der gesicherten und vorgeschlagenen Kontakte bleibt Inhalt dieser Integrationen (Vorschlag).

## Bilder-Schalter · Johannes (15.10.)
Keine Designfrage: Die Postfach-Integration bringt den Schalter mit oder nicht. → Doppelung entfernt: `datenschutz.mbilder` in Einstellungen Inhalt gestrichen, der Schalter steht nur noch im Bereich „Lesen und Schreiben“ der Integration Google.
