# Antwort Design an Code · 28.10.2026
Zur Rückgabe 27.10. (Bezug main fefe945). Arbeitsstand, nicht freigegeben.

ERLEDIGT
- Postfachstapel (ALFA Mail.dc.html:32–36, Logik :494–:700, :923): alle Werte der Rückgabe als Tokens, Werte unverändert.
  motion.duration: deckOpen 560, deckOpenStagger 45, deckCloseStagger 30, envelopeFirst 420, envelopeSecond 480, envelopeThird 540,
  envelopeSecondDelayOpen 40, envelopeThirdDelayOpen 80, envelopeSecondDelayClose 20, flapOpen 520, flapOpenDelay 120, flapClose 260,
  switchFade 420, switchGhostFade 320, switchContentFade 520, glassDelay 40 (dazu bestehend deckClose 380, switchIn 360, switchOut 760, switchLift 620).
  motion.easing: deckOpen (.3,1.32,.5,1), deckClose (.4,0,.2,1), envelopeSpring (.34,1.56,.64,1), glassIn (.37,0,.63,1), glassOut (.33,0,.15,1).
  opacity.switchGlass .72 · size.ghostShadowOffset 8, ghostShadowBlur 24, ghostShadowSpread −12 · color.ghostShadow rgba(0,0,0,.22), color.ghostRing rgba(0,0,0,.06) · size.envelopeStroke 1.15.
  Versatz je Karte: Karte k öffnet mit k × deckOpenStagger, schließt mit (n−1−k) × deckCloseStagger.
- size.recipientPaddingOpen gestrichen.
- Fundstellen in contract/components.json neu aus den Bögen erzeugt (t2): 223 von 223 stimmen.

NICHT ÜBERNOMMEN / OFFEN
- Textschlüssel: Design hat keinen Zugriff auf Resources/Localizable.xcstrings (Repo nicht verbunden). Bitte Datei mitgeben, dann ordnet Design zu.
- N32 stored/orphaned: liegt bei Johannes.
- N37 Assistent: in Arbeit bei Design.
- LIEF-T8: Schema delivery.schema.json verlangt weiter where; bitte Dateipfad im Schema zulassen, dann setzt Design T8 auf contract/changes.json.

LAUF 28.10. 11:00: P1 contract: valid · P2 consistent · P3 log matches (628) · P4 delivery: complete, items 28 of 44 done.

NACHTRAG 28.10. (nach Abgleich main 2a783dd)
- MAIL-G01: Johannes „ja umstellen“ → Mail linke Bahn 224 bis 280. Neu size.mailLaneMinimumLeft 224 (= Code mailLaneMinimumLeft). Einstellungen unverändert.
- Fläche der Postfächer: Johannes „lack“ → Vorgabe surface lacquer in ALFA Mail und ALFA Einstellungen.
- N32 gestrichen (stored/orphaned), Lieferschein N32 done.
- Lauf 28.10. 12:45: P1 contract: valid · P2 consistent · P3 log matches (629) · P4 delivery: complete.

N37 ASSISTENT (28.10. 15:20)
- Gezeichnet in ALFA Shell (data-part assistant, assistant-thread, assistant-message [user, assistant, streaming, failed], assistant-activity [ok, error], assistant-card, assistant-attachment [sent, pending], assistant-scope, assistant-input [rest, busy, disabled]); Texte shell.assistant*, de/en in contract/texts.json.
- Aus deinem Code übernommen: ContentBlock text, toolActivity, mailDraft/andere Entwürfe (eine Karte), image/document (Datei-Chip), unreadable; TurnStatus complete/streaming/failed; ConversationScope home/project (Zeile über der Eingabe); AttachmentStore-Grenzen als Tokens count.chatDocumentByteLimit 20000000, count.chatTextCharacterLimit 120000; PrivacyCategory aus → Aktivität mit Fehler („{category} ist für den Assistenten aus“); ChatStore.clear → Verlauf löschen mit Rückgängig.
- Nicht gezeichnet (bitte nach Bedarf zurückgeben): Aktion der Entwurfskarte, ContentBlock estimate/estimateBreakdown/calendarLink/driveFiles/contact-/task-/appointment-/cart-/fileDraft je eigene Form, Bildvorschau, Tool-Aktivität je Dienst. Mehrere Entwürfe teilen heute eine Karte (Art, Titel, Zeile).
- N38 offen: Blob bei „Assistent ganz aus“, Sync je Bereich, Zeit im Tooltip.
- Neu: opacity.disabled 0.4 (= SheetValues.disabledOpacity).
- Lauf: P1 contract: valid · P2 consistent · P3 log matches (667) · P4 delivery: complete.
