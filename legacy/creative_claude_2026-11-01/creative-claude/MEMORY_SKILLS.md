# Gedächtnis & Skills – wie das Küchentraining bleibend wird

Stand 31.10.2026 · Entwurf für Agents · Zielsystem ALFA OS über die Claude-Plattform-API. Belege am Ende (Kürzel in eckigen Klammern).

## 0 Kurz
Das Training wird nicht „ins Modell“ gelernt, sondern als **externes, versioniertes Gedächtnis**: Fertiges, geprüftes Wissen wird zum **Skill** (prozedural + Nachschlagewerk), laufende Erfahrung bleibt im **Memory** der App, bis sie sich bewährt. Gewichte des Modells ändern sich nicht; alle hier zitierten Agent-Lernverfahren arbeiten ohne Parameter-Update [ExpeL][Voyager][AWM][Reflexion].

## 1 Begriffe (Leitwörter)
Nach der Taxonomie von CoALA [CoALA] und dem Survey [Du26]:
- **Arbeitsgedächtnis** = Kontextfenster des aktuellen Laufs.
- **Episodisch** = konkrete Erfahrungen: ein Projekt, ein Testlauf, eine Nutzerkorrektur.
- **Semantisch** = abstrahiertes Wissen: unsere **Atome** (Regel, Maß, Muster, Stil).
- **Prozedural** = wiederverwendbare Fähigkeiten: **Skill** (Anleitung + Skripte, z. B. Korpus-Baustein, Prüfroutine).
Die eigentliche Schwierigkeit ist die **Übergangsregel** zwischen den Typen (Episode → Atom → Skill) [Du26].

## 2 Was die Forschung belegt
| Befund | Quelle | Folgerung für uns |
|---|---|---|
| Erkenntnisse als Textliste mit **ADD / EDIT / UPVOTE / DOWNVOTE**; Einträge mit Zähler 0 werden gelöscht; Leistung steigt mit Erfahrung, ohne Gewichts-Update | [ExpeL] | Unsere Atome mit `treffer/gegen` sind genau dieses Schema. Zähler steuern Aufnahme/Löschung. |
| Skill-Bibliothek: Skill wird **erst nach Selbstverifikation** aufgenommen; Skills sind ausführbarer Code, komponierbar; mit Bibliothek deutlich weniger Iterationen in neuer Welt | [Voyager] | Nur geprüfte Bausteine (Korpus-Funktionen, Prüfroutine) wandern in den Skill. |
| Wiederkehrende Abläufe aus erfolgreichen Läufen als **Workflows mit Platzhaltern** abstrahieren; offline (aus Beispielen) und online (aus eigenen Läufen) | [AWM] | Planungsabläufe („Raum → Zeile → Geräte → Prüfen“) als Workflow-Atome mit Platzhaltern statt Projektwerten. |
| Sprachliche Selbstreflexion nach Fehlschlag verbessert den nächsten Versuch | [Reflexion] | Nach jeder Korrektur durch den Nutzer: Reflexion als Episode speichern, nicht sofort als Regel. |
| Gedächtnis-Speicher kippen zwischen **Horten und Amnesie**; Selbstreflexion kann **Fehler verfestigen**; Abhilfe: Probezeit-Puffer, externe Validierung, Gegenbeispiel-Proben, Verfall, Versionierung, Quellenangabe, Widerspruchserkennung | [Du26] | Zweistufig: Kandidaten-Atome in Probezeit; Aufnahme nur nach unabhängiger Bestätigung (andere Projektfamilie). |
| Bewertung in vier Schichten: Aufgabenleistung · Gedächtnisqualität (Präzision, Widerspruchsrate, Veralterung) · Effizienz (Tokens, Latenz) · Governance (Datenschutz, Löschung) ; Regressionstests nach jeder Änderung | [Du26] | Jede neue Skill-Version läuft gegen dieselbe Eval-Suite mit/ohne Skill, familienweise getrennt. |
| Skills laden **schrittweise**: Metadaten immer, `SKILL.md` bei Bedarf, Zusatzdateien nur bei Bedarf; Skripte laufen deterministisch ohne Kontextlast | [AS-Blog] | Atome/Katalog als Zusatzdateien, nicht in SKILL.md; Prüfroutine als Skript. |

## 3 Was die Claude-Plattform bietet (Stand der Doku)
**Agent Skills über API** [Skills-API]
- Upload eines Ordners mit `SKILL.md` (Frontmatter `name` ≤ 64 Zeichen, Kleinbuchstaben/Ziffern/Bindestrich, ohne „claude“/„anthropic“; `description` ≤ 1024 Zeichen) plus Skripte/Dateien; kein Beta-Header mehr nötig.
- **Versionen** sind vollständige Schnappschüsse (`skver_…`); für Produktion **Version pinnen**, `latest` nur zum Testen.
- Nutzung in Messages über `container.skills` (bis 20 je Anfrage), braucht das **Code-Execution-Tool** `code_execution_20250825`; Dateien liegen im Container unter `/skills/<name>/`.
- **Grenzen:** kein Netz, keine Paket-Installation, 30 MB je Skill, isolierter Container.
- **Geltungsbereich = Workspace**; für Mandanten **ein Workspace je Mandant** (bis 100 je Organisation).
- **Nicht von Zero-Data-Retention abgedeckt** → Skills dürfen nur bereinigte, nicht personenbezogene Inhalte enthalten.

**Memory-Tool** [Memory-Tool]
- Werkzeug `{"type":"memory_20250818","name":"memory"}`, ohne Beta-Header; Befehle `view, create, str_replace, insert, delete, rename`.
- **Client-seitig:** Claude fordert nur an; die **App speichert** (bei uns: GRDB in ALFA). Pfade unter `/memories`, Pfad-Traversal strikt prüfen.
- **ZDR-fähig** → richtiger Ort für projekt- und kundennahe Erfahrungen.
- Mit Kontext-Editing/Kompaktierung kombinierbar: Kontext klein halten, Wichtiges im Memory sichern.

## 4 Architektur für ALFA OS
```
             Lauf (Planung/Prüfung)                          Training
Nutzer ─▶ ALFA ─▶ Messages API ──────────────┐        Korpus (bereinigt)
              │   tools: memory_20250818      │              │
              │          code_execution        │              ▼
              │   container.skills: [korpus@skver_X]   Atome v_n (+Zähler)
              ▼                                │              │
      GRDB: /memories (episodisch, je Profil)  │   Lernschleife (familienweise)
              │  Korrekturen, Reflexionen      │              │
              └──────── Konsolidierung ────────┴──▶ Kandidat → Probezeit → Promotion
                                                              │
                                                 Eval-Gate (mit/ohne Skill)
                                                              │
                                              neue Skill-Version (Upload, pinnen)
```
- **Skill `kuechen-korpus` (prozedural + semantisch, statisch):** `SKILL.md` (Ablauf, Kernregeln, Grenzen) · `references/atome.jsonl` (nur bestätigte Atome) · `references/katalog.json` · `scripts/korpus_lib.py` (Bausteine) · `scripts/pruefen.py` (Prüfroutine). Firmenwerte über das **Profil** (siehe ARCHITECTURE.md), nicht im Kern.
- **Memory (episodisch, dynamisch, ZDR):** je Firmenprofil ein `/memories/<profil>/`-Baum in GRDB: Nutzerkorrekturen, Reflexionen, Kandidaten-Atome mit Zählern, offene Fragen.
- **Mandanten:** ein Workspace je Firma/Nutzergruppe; Skill-Versionen je Workspace getrennt.

## 5 Lernzyklus (Übergangsregel)
1. **Episode schreiben**: jeder Lauf/jede Korrektur → Memory (Quelle, Projektfamilie, Datum).
2. **Kandidat bilden**: wiederkehrende Episode → Atom-Kandidat (ADD) mit Zähler 0, Status `probe`.
3. **Prüfen**: Kandidat gegen Testküchen **anderer** Projektfamilien (Hold-out) → `treffer/gegen`; gleiche Familie zählt als zirkulär.
4. **Fördern**: Schwelle erreicht (z. B. ≥ 3 unabhängige Treffer, Gegenquote ≤ 20 %) → Status `bestaetigt`; sonst EDIT (Bedingung schärfen, aufspalten) oder DOWNVOTE.
5. **Vergessen**: Zähler ≤ 0 oder veraltet → löschen/archivieren mit Begründung.
6. **Release**: bestätigte Atome + Skripte → neue Skill-Version; vorher Regression-Evals (mit/ohne Skill, familienweise getrennt); Version pinnen; alte Version für Rollback behalten.
7. **Nutzerfreigabe**: Promotion zu Kernregeln und Profilwerten nur nach Bestätigung durch den Owner.

## 6 Leitplanken
- **Datenschutz:** Kundendaten nur im Memory (ZDR); Skill nur aus bereinigten Daten. Vertrauliche Eingänge nie hochladen.
- **Kein Raster, keine Normen:** Atome sind Projektbeobachtungen mit Bereich, keine allgemeingültigen Ergonomieregeln.
- **Gegen Selbstverfestigung:** externe Validierung (Hold-out, Nutzer), Verfall, Quellenpflicht je Atom [Du26].
- **Messbar:** jede Version mit Kennzahlen (Treffer/Gegen je Bereich, Widerspruchsrate, Tokens) [Du26].

## 7 Stand dieses Projekts
- 202 Atome v1, 45 Testküchen; Lernschleife Runde 1 läuft (Familien-Hold-out). Schwach: Griff-Atome, 600/900-Standard, Passblende 70, Gang 1100 bei freier Insel.
- Offen: Skill-Upload erst nach Owner-Freigabe; Workspace-Zuschnitt; Eval-Suite aus `05_Skills/mykilos-korpus/evals.json` übernehmen.

## Quellen
- [CoALA] Sumers, Yao, Narasimhan, Griffiths (2023): *Cognitive Architectures for Language Agents*. arXiv:2309.02427. https://arxiv.org/abs/2309.02427
- [Voyager] Wang et al. (2023): *Voyager: An Open-Ended Embodied Agent with Large Language Models*. arXiv:2305.16291. https://arxiv.org/pdf/2305.16291
- [ExpeL] Zhao et al. (2023/24): *ExpeL: LLM Agents Are Experiential Learners*. arXiv:2308.10144. https://arxiv.org/html/2308.10144v3
- [AWM] Wang, Mao, Fried, Neubig (2024): *Agent Workflow Memory*. arXiv:2409.07429. https://arxiv.org/html/2409.07429v1
- [Reflexion] Shinn et al. (2023): *Reflexion: Language Agents with Verbal Reinforcement Learning*. NeurIPS 2023. https://arxiv.org/abs/2303.11366
- [Du26] Du (2026): *Memory for Autonomous LLM Agents: Mechanisms, Evaluation, and Emerging Frontiers*. arXiv:2603.07670. https://arxiv.org/pdf/2603.07670
- [AS-Blog] Anthropic Engineering: *Equipping agents for the real world with Agent Skills*. https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- [Skills-API] Claude Docs: *Using Agent Skills with the API*. https://platform.claude.com/docs/en/api/skills-guide
- [Memory-Tool] Claude Docs: *Memory tool*. https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
