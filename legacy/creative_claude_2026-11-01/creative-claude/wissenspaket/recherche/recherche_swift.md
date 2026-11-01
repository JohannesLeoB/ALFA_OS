# Recherche: Swift-Kern für das Küchen-/Möbel-Planungssystem

Stand: 31.10.2026 · Methode: nur Websuche/Webseiten · Legende: **[belegt]** = durch verlinkte Quelle gestützt · **[unsicher]** = Quelle dünn, widersprüchlich oder nicht nachgeprüft · **[Einschätzung]** = eigene Bewertung.
Zeilenschätzungen = Produktivcode ohne Tests, Swift 6.2, ohne Kommentarblöcke [Einschätzung].

---

## 1. B-Rep/STEP aus Swift

**OCCTSwift**
- Lizenz LGPL-2.1; README nennt v3.0.0 „SemVer-stable“, auf GitHub aber keine Releases; 15 Stars, 4.218 Commits; OCCT 8.0.1 laut Intro, 8.0.0p1 laut Ökosystem-Tabelle (widersprüchlich) [belegt].
- Plattformen: macOS 12+/iOS 15+ arm64 unterstützt; Linux/Windows/Android „under review“ [belegt]. Aufbau: Swift-API → C-Brücke in Objective-C++ → OCCT; Nutzer brauchen kein `.interoperabilityMode(.Cxx)` [belegt].
- Export STEP, IGES, STL, OBJ, PLY, BREP, glTF/GLB, DXF [belegt]. OCCT wird als **statische** Bibliotheken in ein xcframework gepackt, ~568 MB für 3 Slices, 16 Pflicht-Module inkl. TKSTEP [belegt].
- Umfeld: 14 Pakete derselben Org (u. a. OCCTMCP, OCCTSwiftIO, OCCTSwiftViewport), zusammen 24 Stars, letzte Aktivität vor ~1–2 Wochen [belegt].
- Bewertung: technisch weit, aber kleine Org (Bus-Faktor), kein Linux, statisches Linken (Lizenzpflichten, s. u.), riesiges Binärpaket → **nicht als Kern-Abhängigkeit**; höchstens später als optionaler macOS-Adapter prüfen [Einschätzung]. Andere Swift-Bindings für OCCT wurden nicht gefunden [unsicher].
- OCCT 8.0.0 erschien am 07.05.2026: C++17 Pflicht, `Standard_Failure` erbt von `std::exception`, STEP lesen/schreiben thread-sicher (eine Instanz je Thread) [belegt].

**Swift-C++-Interop vs. Objective-C++-Brücke**
- C++-Interop läuft auf allen Swift-Plattformen inkl. Linux [belegt]. Grenzen: keine R-Value-Referenzen, Klassen-Templates nur über Spezialisierungen per typedef, **C++-Exceptions nicht fangbar (Programmabbruch)**, und Interop „steckt an“: abhängige SwiftPM-Ziele müssen es ebenfalls einschalten [belegt].
- Objective-C++ gibt es unter Linux nicht; eine ObjC++-Brücke müsste für die SaaS neu geschrieben werden [Einschätzung].
- Empfehlung, falls je OCCT im Prozess: dünne `extern "C"`-Schicht in C++ (fängt OCCT-Exceptions, stabile C-ABI, gleich auf macOS/Linux), Swift sieht nur C [Einschätzung].

**OCCT-Lizenz in der macOS-App und im SaaS-Betrieb**
- OCCT: LGPL 2.1 + „Open CASCADE Exception 1.0“. Die Ausnahme erlaubt Objektcode mit Material aus OCCT-Headern (inkl. generischer Klassen) unter eigenen Bedingungen, verlangt aber einen deutlichen Hinweis in der Doku [belegt].
- LGPL 2.1 §6: entweder (a) das eigene Werk als Objekt-/Quellcode mitliefern, damit Nutzer neu linken können, oder (b) ein „suitable shared library mechanism“, der mit einer vom Nutzer installierten, schnittstellengleichen Version funktioniert. Außerdem müssen die Bedingungen Reverse Engineering zum Debuggen erlauben [belegt].
- Statisch (wie OCCTSwift) ⇒ Variante (a): Objektdateien plus Link-Skript ausliefern. Das geht, ist aber lästig [Einschätzung]. Dynamisch (dylibs/Frameworks im Bundle) ⇒ Variante (b). Mit Hardened Runtime/Library Validation lädt eine ausgetauschte, anders signierte dylib aber nicht ohne Neusignieren der App. Ob das §6b genügt, ist eine juristische Grauzone ⇒ **Rechtsprüfung vor Auslieferung** [Einschätzung]. Ob das im Mac App Store zulässig ist: [unsicher].
- SaaS: LGPL-Pflichten entstehen durch Weitergabe. Reiner Serverbetrieb ohne Auslieferung von Binärdateien löst sie nicht aus (LGPL hat anders als AGPL keine Netzwerkklausel) [Einschätzung].

**Reine STEP-Writer ohne Kern**
- cadmpeg-step (Rust, Apache-2.0): schreibt ISO 10303-21 als AP214, Option AP242 Ed. 3, Körper als `MANIFOLD_SOLID_BREP` / `BREP_WITH_VOIDS` [belegt].
- stepts (TypeScript, MIT): Parsen/Erzeugen/Serialisieren, Beispiel „Simple Box“, Prüfung über externe Kerne (occt-import-js) [belegt]. Einen Swift-STEP-Writer fanden wir nicht [unsicher].
- Selbst schreiben, nur für achsparallele Quader: Part-21-Text; Produkt-/Kontext-Kette (~25 Entities), je Quader 8 `VERTEX_POINT`, 12 `EDGE_CURVE`/`LINE`, 6 `ADVANCED_FACE`/`PLANE`, `CLOSED_SHELL`, `MANIFOLD_SOLID_BREP`; Farben über `STYLED_ITEM`; Baugruppe über `NEXT_ASSEMBLY_USAGE_OCCURRENCE`. Umfang **600–1.200 Zeilen** [Einschätzung].
- Grenze: Bohrungen und Nuten als echte Geometrie brauchen Boolesche Operationen ⇒ Kern bzw. Sidecar [Einschätzung].

Quellen: https://github.com/gsdali/OCCTSwift · https://swiftpackageindex.com/SecondMouseAU · https://gsdali.github.io/OCCTSwift/guides/building-occt.html · https://occt3d.com/dev/content/open-cascade-technology-800-release/index.html · https://www.swift.org/documentation/cxx-interop/status/ · https://occt3d.com/dev/doc/overview/html/occt_public_license.html · https://opensource.org/license/lgpl-2-1 · https://docs.rs/crate/cadmpeg-step/latest/source/README.md · https://github.com/tscircuit/stepts

## 2. Mesh/Vorschau (USDZ/glTF)

- ModelIO: `MDLAsset.export(to:)` wählt das Format anhand der Dateiendung; ob ein Format geht, prüft man zur Laufzeit mit `canExportFileExtension` [belegt]. Für USDZ empfiehlt Apple `MDLUtility.convert(toUSDZ:writeTo:)` [belegt]. Nur Apple-Plattformen [Einschätzung].
- RealityKit (macOS 26): `Entity.write(to:options:)` schreibt `.reality`-Dateien, **kein USDZ** [belegt].
- USDKit: neues Systemframework (WWDC26), `USDStage.exportPackage` [belegt]. Mindest-OS steht nicht in der Quelle; im Umfeld ist von macOS 27 die Rede ⇒ für ein macOS-26-Ziel vermutlich nicht verfügbar [unsicher].
- SwiftUSD (OpenUSD per C++-Interop): Linux ja, Tomorrow-Open-Source-Lizenz, 87 Stars, bringt Boost, Python und OpenVDB mit [belegt] ⇒ für Quader-Vorschau viel zu schwer [Einschätzung].
- glTF in Swift:
  - SwiftGLTF: BSD-3, 52 Stars, nur Laden/Parsen, kein Export [belegt].
  - GLTFKit2: MIT, 235 Stars, Export „WIP“ und nicht abgehakt, Apple-Fokus [belegt].
  - Einen Linux-fähigen Swift-glTF-**Writer** gibt es auf dem Swift Package Index nicht [belegt].
- Selbst schreiben:
  - glTF 2.0/GLB-Writer (JSON + Binärpuffer; Quader mit 24 Vertices/36 Indizes, Normalen, PBR-Grundfarbe je Material, Knotenhierarchie): **300–500 Zeilen**, läuft auf Linux und WebAssembly [Einschätzung].
  - USDA-Text plus USDZ-Packer (unkomprimiertes ZIP mit 64-Byte-Ausrichtung): zusätzlich **350–550 Zeilen** [Einschätzung]. Auf macOS reicht ModelIO.
- Bohrungen und Nuten in der Vorschau: tessellierte Zylinder bzw. Quader-Einsätze ohne Boolesche Operationen (nur optisch) reichen für die Vorschau [Einschätzung].

Quellen: https://developer.apple.com/documentation/modelio/mdlasset/export(to:).md · https://developer.apple.com/forums/thread/831599 · https://developer.apple.com/documentation/realitykit/entity/writeoptions.md · https://developer.apple.com/videos/play/wwdc2026/285/ · https://github.com/wabiverse/SwiftUSD · https://github.com/schwa/SwiftGLTF · https://github.com/warrenm/GLTFKit2 · https://swiftpackageindex.com/search?query=gltf

## 3. 2D-Zeichnungen/PDF

- **macOS:** `CGContext(url, mediaBox:, auxiliaryInfo)` erzeugt einen PDF-Kontext; Zeichenbefehle landen als PDF-Vektorbefehle in der Datei [belegt]. Das ist der Hauptweg für Maßzeichnungen [Einschätzung].
- **WKWebView als HTML→PDF-Weg (macOS):**
  - `createPDF` liefert eine einzige, sehr hohe Seite [belegt].
  - `printOperation` paginiert, hat aber einen offenen Fehler (FB20581927): falsche Seitenzahl, abgeschnittene Ausgabe, reproduziert noch auf macOS 26.1 Beta [belegt].
  - ⇒ Für mehrseitige Dokumente auf macOS 26 riskant [Einschätzung].
  - swift-pdf (Org swift-foundations) kapselt genau diesen WKWebView-Weg (1.0.5) [belegt].
- **Linux, reines Swift:**
  - TPPDF: MIT, 838 Stars, 2.6.1 vor ~2 Jahren, 3.0.0-alpha.1 vor 10 Monaten, keine Abhängigkeiten; der Swift Package Index listet Linux [belegt]. Ob unter Linux echte PDF-Ausgabe entsteht (TPPDF baut auf CoreGraphics/UIKit/AppKit auf), ist offen [unsicher].
  - SwiftlyPDFKit 0.2.0 nutzt unter Linux das externe Binary wkhtmltopdf [belegt].
  - SwiftyHaru (Wrapper um libharu): MIT, 0.3.0, seit 7 Jahren still [belegt] ⇒ ungepflegt.
  - libharu selbst: ZLIB/LIBPNG-Lizenz, ~2,0k Stars, TrueType-Einbettung [belegt]. Wäre als vendortes C-Ziel nutzbar [Einschätzung].
- **Eigener minimaler PDF-Writer:** Linien, Bögen als Bézier, Text in Standard-14-Helvetica mit WinAnsi (ä/ö/ü/ß), mehrere Seiten: **600–1.000 Zeilen**. Mit TrueType-Einbettung und Subsetting zusätzlich 1.500–3.000 Zeilen; in dem Fall besser libharu oder Typst [Einschätzung].
- **SVG:** ein String-Writer genügt (**200–400 Zeilen**); Swift-SVG-Pakete sind fast nur Renderer [belegt/Einschätzung].
- **HTML/Satz→PDF auf Linux:**
  - Headless Chromium, z. B. Gotenberg (Docker-API, MIT, 12,8k Stars) [belegt].
  - WeasyPrint 70.0 (Python, BSD, auf Seitenumbruch ausgelegt) [belegt].
  - Typst 0.15.1 (17.07.2026, Apache-2.0) liest Daten per `json()` [belegt]. Als Sidecar-Binary auch in der macOS-App denkbar (als sandboxed Helper signiert) [Einschätzung].
- **„Zeichenliste“ im Kern – Vorbilder:**
  - build123d: `ExportSVG` und `ExportDXF` teilen Layer, Linientypen, Strichstärken und `add_shape()`; DXF geht über ezdxf; sichtbare und verdeckte Kanten kommen aus `project_to_viewport()` [belegt].
  - SwiftDraw (Zlib): ein SVG-Modell, mehrere Ausgaben (CoreGraphics, PDF, PNG, SF Symbols, Swift-Code) [belegt].
  - Bewertung: abstrakte Zeichenliste mit Renderern für CoreGraphics-PDF, SVG und DXF ist **klar zu empfehlen** und erprobtes Muster [Einschätzung].

Quellen: https://developer.apple.com/tutorials/data/documentation/coregraphics/cgcontext/init(_:mediabox:_:).md · https://developer.apple.com/forums/thread/803249 · https://developer.apple.com/forums/thread/700418 · https://github.com/swift-foundations/swift-pdf/releases · https://swiftpackageindex.com/techprimate/TPPDF · https://swiftpackageregistry.com/Swiftly-Developed/Swiftly-PDFKit · https://swiftpackageindex.com/WeirdMath/SwiftyHaru · https://github.com/libharu/libharu · https://github.com/gotenberg/gotenberg · https://doc.courtbouillon.org/weasyprint/stable/ · https://github.com/typst/typst/releases · https://typst.app/docs/reference/data-loading/json/ · https://build123d.readthedocs.io/en/latest/import_export.html · https://github.com/swhitty/SwiftDraw · https://swiftpackageindex.com/search?query=svg

## 4. Vorlagen (Mustache)

| Paket | Lizenz | Letzter Release | Pflege | Linux | Abh. | Spec |
|---|---|---|---|---|---|---|
| swift-mustache (Hummingbird) | Apache-2.0 | 2.1.1, vor ~1 Monat | 83★, 179 Commits, aktiv (Main vor 22 h) | ja (+Wasm, Android) | **0** | voll konform außer Lambdas; Vererbung, Transforms, Pragmas als Extras |
| GRMustache.swift | MIT | 7.0.0, vor ~1 Jahr | 629★, Aktivität vor ~1 Jahr | gelistet | 0 | k. A. |
| Stencil | BSD-2 | 0.15.1, vor 4 Jahren | 2.410★, stagniert | gelistet | 2 | kein Mustache (Jinja-artig) |

Alle Tabellenangaben [belegt], „stagniert“ [Einschätzung].
- Mustache-Spec: YAML-Testdateien; Kern = Dateien ohne `~`, optional = mit `~` (z. B. Lambdas); MIT [belegt].
- Selbst schreiben: Kern-Spec (Interpolation mit Escaping, Sections, Inverted, Comments, Partials, Set Delimiter) **500–900 Zeilen** plus ~150 Zeilen Spec-Testläufer [Einschätzung].
- Empfehlung: swift-mustache (0 transitive Abhängigkeiten, aktiv, Apache-2.0) ist der beste Kandidat für eine Owner-Freigabe; sonst selbst schreiben [Einschätzung].

Quellen: https://github.com/hummingbird-project/swift-mustache · https://swiftpackageindex.com/hummingbird-project/swift-mustache · https://github.com/hummingbird-project/swift-mustache/blob/main/Package.swift · https://swiftpackageindex.com/groue/GRMustache.swift · https://swiftpackageindex.com/stencilproject/Stencil · https://github.com/mustache/spec

## 5. DXF/DWG

- **Swift:**
  - SwiftDXF (SecondMouseAU): MIT, **nur Lesen** von ASCII-DXF in 2D, 3 Stars, 28 Commits, v0.1.0 [belegt].
  - Einen Swift-DXF-**Writer** gibt es auf dem Swift Package Index nicht [belegt].
- **C/C++:**
  - libdxfrw: GPL-2.0-or-later, DXF lesen/schreiben (ASCII + binär), DWG experimentell, 293 Stars [belegt].
  - dxflib: GPLv2+ oder kommerzielle Lizenz (QCAD) [belegt].
  - ⇒ Beide sind für eine Closed-Source-App ungeeignet, außer mit gekaufter Lizenz [Einschätzung].
- **DWG:**
  - LibreDWG: GPLv3, letzter stabiler Release 0.13.3 (26.02.2024), schreibt nur R2000 (seit 0.12.5) [belegt]. Nur serverseitig ohne Weitergabe denkbar [Einschätzung].
  - ODA-Mitgliedschaft [belegt]:
    - Commercial: 3.000 $ Einstieg, 2.250 $/Jahr, „limited commercial use“.
    - Sustaining: 7.500 $ / 4.500 $ pro Jahr, unbegrenzte kommerzielle Nutzung.
    - Founding: 37.500 $ / 18.000 $ pro Jahr, inkl. Quellcode.
    - Endet die Mitgliedschaft, endet auch das Vertriebsrecht.
  - Dazu käme eine eigene C-Brücke zum ODA-C++-SDK [Einschätzung].
- **Minimaler Writer selbst:**
  - R12 kommt mit nur der ENTITIES-Sektion aus (ezdxf-r12writer: LINE, CIRCLE, ARC, TEXT, POINT, SOLID, 3DFACE, POLYLINE; mit `fixed_tables` auch Linientypen) [belegt].
  - AC1015/R2000 verlangt [belegt]:
    - HEADER mit `$ACADVER` und `$HANDSEED`
    - CLASSES
    - TABLES: LTYPE, LAYER, STYLE, APPID, DIMSTYLE, BLOCK_RECORD
    - BLOCKS mit `*MODEL_SPACE` und `*PAPER_SPACE`
    - OBJECTS mit Root-DICTIONARY und ACAD_GROUP
    - Handles
  - Umfang: R12 mit Layern und Linientypen **300–500 Zeilen**; AC1015 mit Handles, Owner-Bezügen, LWPOLYLINE und MTEXT **1.000–1.800 Zeilen** [Einschätzung].
  - Bemaßungen als Linien und Text auflösen statt DIMENSION-Entity; in CI mit ezdxf-audit prüfen (Python nur in CI, nicht in der App) [Einschätzung].

Quellen: https://github.com/SecondMouseAU/SwiftDXF · https://swiftpackageindex.com/search?query=dxf · https://github.com/LibreCAD/libdxfrw · https://community.osarch.org/discussion/comment/7860 · https://en.wikipedia.org/wiki/LibreDWG · https://www.opendesign.com/pricing.md · https://ezdxf.readthedocs.io/en/stable/addons/r12writer.html · https://ezdxf.readthedocs.io/en/stable/dxfinternals/filestructure.html

## 6. Etiketten/Codes

- **CoreImage** hat Generatoren für QR und Code 128 sowie `CIBarcodeGenerator` mit Deskriptor [unsicher – Filternamen nicht einzeln nachgeprüft; das Protokoll ist belegt]. Ob Data Matrix *erzeugt* werden kann, ist offen [unsicher]. Nur Apple-Plattformen [Einschätzung].
- **QR in reinem Swift:** swift-qrcode-generator, MIT, ohne Abhängigkeiten, Linux-CI, weitgehend direkte Übersetzung eines bekannten MIT-lizenzierten Rust-QR-Generators, 53 Stars, 66 Commits [belegt]. Datum des letzten Releases: [unsicher].
- **Data Matrix:** kein Swift-Paket auf dem Swift Package Index [belegt]. zint (libzint) [belegt]:
  - Bibliothek unter BSD-3, GUI und CLI unter GPLv3.
  - Kann Data Matrix, Code 128/GS1-128 und QR; Ausgabe u. a. als SVG und EPS; 800 Stars.
  - ⇒ Als vendortes C-Ziel möglich, läuft unter Linux [Einschätzung].
  - BarCodeKit (nur 1D, 92 Stars, seit 3 Jahren still) [belegt].
- **ZPL:** ZPLKit existiert (2 Stars) [belegt]. ZPL ist Text und hat eigene Barcode-Befehle (`^BC` Code 128, `^BQ` QR, `^BX` Data Matrix); bei Zebra-Druckern rendert der **Drucker** die Codes, ein eigener Encoder ist dort nicht nötig [Einschätzung].
- **Selbst schreiben** [Einschätzung]:
  - Code 128 (Sets B/C, Prüfsumme): **150–250 Zeilen**
  - QR (Port des MIT-Codes): **1.000–1.300**
  - Data Matrix ECC200 (Reed-Solomon GF(256), Platzierung, Symbolgrößen): **700–1.200**
  - ZPL-Builder: **100–200**

Quellen: https://developer.apple.com/tutorials/data/documentation/coreimage/cibarcodegenerator.md · https://github.com/fwcd/swift-qrcode-generator · https://github.com/zint/zint · https://swiftpackageindex.com/search?query=datamatrix · https://swiftpackageindex.com/search?query=barcode

## 7. Zuschnitt/Nesting und Autoplanung

- Der Swift Package Index liefert für „bin packing“, „rectangle packing“ und „packing“ kein passendes Paket [belegt].
- **Vorlage:** RectangleBinPack (C++, Public Domain, 991 Stars) mit MaxRects, Guillotine, Skyline und Shelf, dazu das Paper „A Thousand Ways to Pack the Bin“ [belegt].
- **Port nach Swift** [Einschätzung]:
  - Guillotine mit Schnittfuge, Besäumung und Faserrichtung (Drehverbot): **400–800 Zeilen**
  - MaxRects: **300–500**
  - Skyline: **200–300**
  - Mehrfachstart, Restteile und Bewertung: **~500**
- Plattensägen brauchen Guillotine-Schnittbilder; MaxRects passt eher zum CNC-Nesting [Einschätzung].
- **Solver:**
  - OR-Tools v9.15 (12.01.2026): Apache-2.0, C++-Kern mit Python/C#/Java-Wrappern, keine Swift-Anbindung [belegt]. C++-Interop wäre schwer (großer Abhängigkeitsbaum) [Einschätzung].
  - HiGHS: MIT, C-API, keine Drittabhängigkeiten, LP/MIP [belegt] ⇒ als C-Ziel aus Swift machbar, auch unter Linux [Einschätzung].
  - MiniZinc: MPL-2.0, CLI, Solver nicht im Repo [belegt].
- **Empfehlung:** Optimierende Autoplanung (CP-SAT) als Python-Sidecar mit JSON-Schnittstelle; im Kern nur deterministische Heuristiken [Einschätzung].

Quellen: https://swiftpackageindex.com/search?query=bin+packing · https://swiftpackageindex.com/search?query=packing · https://github.com/juj/RectangleBinPack · https://github.com/google/or-tools/releases · https://github.com/google/or-tools · https://github.com/ERGO-Code/HiGHS · https://github.com/MiniZinc/libminizinc

## 8. MCP in Swift

- **swift-sdk (modelcontextprotocol)** [belegt]:
  - Stand: aktuell **0.12.1 vom 07.05.2026** (Releaseseite ohne Jahr; das Jahr folgt aus der Reihenfolge und der Angabe „vor ~6 Monaten“ beim Swift Package Index). 1,6k Stars, 121 Commits, Main zuletzt vor 6 Tagen geändert. Lizenz: MIT für Altcode, Apache-2.0 für neue Beiträge.
  - Spec 2025-11-25 seit 0.11.0 (19.02.2026); dort kam auch der Server-HTTP-Transport dazu.
  - Transporte laut README: `StdioTransport`, `HTTPClientTransport` (Streamable HTTP), `StatelessHTTPServerTransport`, `StatefulHTTPServerTransport` (Sessions + SSE), `NetworkTransport` (nur Apple), `InMemoryTransport`. Ob alle Server-Transporte schon im Release 0.12.1 stecken: [unsicher].
  - Linux mit glibc und musl; Build mit Static Linux SDK seit 0.10.1.
  - Swift 6.0+. `Package.swift` (Main) zieht swift-system, swift-log, eventsource und swift-nio (+ docc-plugin) ⇒ 4–5 neue Abhängigkeiten gegen die „nur GRDB“-Regel [Einschätzung].
- **Selbst schreiben:** stdio-Server (JSON-RPC 2.0, `initialize`, `tools/list`, `tools/call`, Benachrichtigungen) **600–1.000 Zeilen**. Streamable-HTTP-Server erst in der SaaS, dann auf dem Server-Framework [Einschätzung].
- **Anbindung einer sandboxed macOS-App:**
  - Claude Desktop: lokale Server als MCPB (ZIP + `manifest.json`, **stdio**, Binaries erlaubt, statisch gelinkt bevorzugt, macOS/Windows). Remote-Konnektoren laufen über HTTPS auf eigenen Servern und werden über Anthropics Infrastruktur erreicht [belegt]. Ein localhost-Server in der App ist daraus also nicht direkt nutzbar [Einschätzung].
  - Apple: ein eingebetteter Helper bekommt nur `app-sandbox` + `inherit` und läuft als Kindprozess der App [belegt]. Startet ein fremder Prozess (Claude Desktop) ihn, greift `inherit` nicht.
  - Praxisbericht: sandboxed Standalone-CLIs werden beim Start durch fremde Apps von AMFI abgelehnt. Lösung dort: ein Proxy nur im Developer-ID-Build (stdio → HTTPS 127.0.0.1 auf einen Server in der App); Claude Desktop nehme in der Config nur stdio-Einträge [belegt als Einzelbericht, verallgemeinert unsicher].
  - Apple-DTS-Muster für App ↔ separaten Prozess: XPC-Named-Endpoint mit Namen **innerhalb einer App Group**; beide Programme beanspruchen die Gruppe; der Helper steckt in einem app-artigen Wrapper mit Provisioning Profile [belegt]. Mach-Namen müssen unter dem App-Group-Präfix liegen [belegt].
  - Claude Code: `claude mcp add --transport http <name> <url>` sowie stdio [belegt]; ob localhost-URLs gehen, ist nicht ausdrücklich dokumentiert [unsicher].
- **Empfehlung:** MCP-Server als eigenes Executable mit eigener Sandbox und App Group, **nicht** `inherit` [Einschätzung].
  - Liest die GRDB-Datenbank im App-Group-Container und schickt Schreibbefehle per XPC an die App.
  - Wird als MCPB für Claude Desktop ausgeliefert, für Claude Code als stdio-Pfad.
  - Zuerst Developer ID; App-Store-Tauglichkeit: [unsicher].

Quellen: https://github.com/modelcontextprotocol/swift-sdk · https://github.com/modelcontextprotocol/swift-sdk/releases · https://swiftpackageindex.com/modelcontextprotocol/swift-sdk · https://github.com/modelcontextprotocol/swift-sdk/blob/main/Package.swift · https://claude.com/docs/connectors/building/mcpb.md · https://github.com/modelcontextprotocol/mcpb · https://developer.apple.com/tutorials/data/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app.md · https://github.com/joergs-git/AstroBlinkV2/releases/tag/v6.4.0 · https://developer.apple.com/forums/thread/835003 · https://developer.apple.com/forums/thread/808940 · https://code.claude.com/docs/en/mcp

## 9. Server-Swift für die SaaS

- **Vapor:** 4.122.2 (vor ~1 Monat), **5.0.0-beta.4** (vor 5 Tagen), MIT, 26.231 Stars, 29 transitive Abhängigkeiten, Linux, Swift 6.1–6.4 [belegt].
- **Hummingbird:** 2.28.1 (vor wenigen Stunden), Apache-2.0, 1.901 Stars, 23 transitive Abhängigkeiten [belegt]. Minimalistisch, Structured Concurrency „nativ“ [belegt laut einem einzelnen Vergleichsartikel].
- **Bewertung:** Hummingbird passt zu einem schlanken Kern (gleiche Org wie swift-mustache). Vapor 5 erst nach dem finalen Release erwägen [Einschätzung].
- **Static Linux SDK** [belegt]:
  - musl-basiert, vollständig statische Binärdateien.
  - **kein dlopen**, keine Systembibliotheken (nur die mitgelieferten wie libxml2, zlib, curl).
  - Foundation und SwiftNIO „should just work“; `import Glibc` muss auf Musl umgestellt werden.
- **WebAssembly:**
  - Offizielle SDKs seit Swift 6.2, plus Embedded-Variante (Hello World 9,7 kB); Foundation und XCTest waren zum Start nicht enthalten [belegt].
  - Produktionsbeispiel Goodnotes (swift.org, 01.06.2026): 2,2 Mio. Zeilen, 50 MB Binary bzw. 12 MB mit Brotli, kein libdispatch, WASI-Threads [belegt].
  - JavaScriptKit 0.54–0.56 mit BridgeJS (Juni 2026) [belegt].
  - ⇒ Reif genug für eine Browser-Vorschau, wenn der Kern ohne Dispatch und mit wenig Foundation auskommt. Einfacher ist: Server erzeugt GLB, der Browser rendert mit three.js [Einschätzung].

Quellen: https://swiftpackageindex.com/vapor/vapor · https://swiftpackageindex.com/hummingbird-project/hummingbird · https://www.pistack.xyz/posts/2026-07-06-swift-server-side-frameworks-vapor-hummingbird-grpc-swift/ · https://www.swift.org/documentation/articles/static-linux-getting-started.html · https://swift.org/documentation/articles/wasm-getting-started.html · https://forums.swift.org/t/swift-sdks-for-webassembly-now-available-on-swift-org/80405 · https://swift.org/blog/bringing-goodnotes-to-web-with-swift/ · https://forums.swift.org/t/swift-for-wasm-june-2026-updates/87820

## 10. Mehrsprachigkeit – ehrlich

| Bereich | In Swift? | Begründung |
|---|---|---|
| Domäne, Regeln, Stückliste, Ansichten-Projektion achsparalleler Quader | **ja** | einfache Geometrie, Kern-IP |
| Zeichenliste → SVG / DXF R12+AC1015 / CG-PDF | **ja** | je wenige 100–1.800 Zeilen |
| glTF/GLB, STEP für planare Quader | **ja** | Text/Binär-Serialisierung, kein Kern nötig |
| Codes, ZPL, Mustache, MCP-stdio | **ja** | überschaubar, spec-getrieben |
| Zuschnitt-Heuristiken | **ja** | gut dokumentierte Algorithmen |
| STEP mit echten Bohrungen/Nuten, Fasen, Freiformen, STEP-**Import** fremder Modelle | **nein → Sidecar** (Python build123d/OCCT oder Fusion) | Boolesche Operationen und B-Rep-Heilung sind Jahre an Kernarbeit |
| DWG lesen/schreiben | **nein** → ODA oder Konverter-Dienst | Format proprietär, freie Libs GPL |
| Optimierende Autoplanung (Constraints) | **nein → Python OR-Tools** | keine Swift-Bindung, C++-Interop teuer |
| Linux-PDF mit eingebetteten Schriften und Satz | **eher nein** → Typst/libharu | Font-Subsetting ist teuer |

Alle Zeilen [Einschätzung]. Summe des selbst zu schreibenden Codes ≈ **8.000–13.000 Zeilen** ohne Tests [Einschätzung].

---

## Empfehlung Code-Design Swift-Kern

**Paketschnitt (ein SwiftPM-Workspace; Kernpakete ohne Apple-Frameworks):**
```
Kern/            Domäne aus dem JSON-Modell (Codable), Validierung, Regeln, Stückliste
Geometrie/       Quader, Transformationen, 2,5D-Bearbeitungen, Ansichten/Schnitte → Kanten
Zeichnung/       DisplayList (Layer, Linientyp, Strichstärke, Linie/Bogen/Polylinie/Text/Bemaßung, Seite)
  ├ SVGRenderer, DXFRenderer (R12 → AC1015), MiniPDFRenderer (Linux-Fallback)
Mesh/            Triangulierung + glTF/GLB-Writer
STEPWriter/      AP214, planare B-Reps, Baugruppe, Farben
Vorlagen/        Mustache (eigen oder swift-mustache nach Freigabe)
Codes/           Code128, QR, DataMatrix, ZPL-Builder
Zuschnitt/       Guillotine, MaxRects, Skyline + Bewertung
MCPKern/         Tool-Schemas, JSON-RPC-Dispatcher, transportfrei
Adapter-Apple/   CoreGraphics-PDF, ModelIO-USDZ, (CoreImage optional)  – #if canImport
Adapter-GRDB/    Persistenz (einzige erlaubte Abhängigkeit)
Adapter-Sidecar/ JSON-Protokoll zu build123d/OCCT, OR-Tools, Typst (Prozess oder HTTP)
App-macOS/, MCP-Helper/, später Server-Hummingbird/
```
**Ports (Protokolle im Kern) → Adapter:**
- `ZeichnungsRenderer` → CG-PDF | SVG | DXF | MiniPDF
- `MeshExporter` → GLB | USDZ (ModelIO)
- `BRepDienst` (`exportSTEP`, später `boolean`) → eigener Quader-Writer | Sidecar | optional OCCTSwift
- `Optimierer` → Heuristik | OR-Tools-Sidecar
- `DokumentSetzer` → CG-PDF | Typst
- `Speicher` → GRDB | Server-DB
- `Uhr`/`IDs` für Determinismus

[alles Einschätzung]

**Regeln** [Einschätzung]:
- Kernpakete importieren höchstens `FoundationEssentials` (`#if canImport`), kein Dispatch ⇒ Linux, Static SDK und Wasm bleiben offen.
- Ausgaben deterministisch (sortierte Schlüssel, feste Zahlenformatierung) ⇒ Golden-File-Tests.
- CI-Validierung mit externen Werkzeugen (ezdxf-audit, OCCT-Import für STEP, glTF-Validator); diese laufen nur in CI und werden nicht ausgeliefert.

**Owner-Entscheidungen (Kandidaten)** [Einschätzung]:
- swift-mustache: Apache-2.0, 0 transitive Abhängigkeiten.
- swift-qrcode-generator (MIT) oder eigener Port.
- zint als vendortes C-Ziel (BSD-3) für Data Matrix.
- MCP-swift-sdk (+4–5 Abhängigkeiten) gegen eigenen stdio-Server; Empfehlung: eigener Server.
- OCCT nur als Sidecar, nicht in der App.

## Offene Fragen

1. Muss STEP Bohrungen und Nuten als echte Geometrie enthalten, oder reichen Quader plus Bearbeitungsliste? Davon hängt ab, ob ein Kern nötig ist.
2. Welche Maschinen und CAM-Systeme werden beliefert, mit welchen DXF-Layer-Konventionen oder nativen Formaten (z. B. MPR, BTLx)? Ist DWG wirklich Pflicht?
3. Vertrieb über Developer ID oder Mac App Store? Das entscheidet über MCP-Helper, Sidecars und die LGPL-Strategie.
4. Welche Claude-Clients sollen angebunden werden (Desktop über MCPB, Code über stdio oder HTTP)? Reicht Lesen, oder soll Claude auch schreiben (XPC-Weg)?
5. Etikettendrucker: ZPL-fähig (Codes rendert dann der Drucker) oder PDF-Etiketten? Ist Data Matrix zwingend?
6. Sind Sidecar-Laufzeiten akzeptabel: Python (build123d/OR-Tools) in der Desktop-App oder nur im SaaS? Typst-Binary in der App?
7. Rechtsprüfung: LGPL-Konformität bei dynamischem OCCT unter Hardened Runtime; Verwendung von GPLv3-Tools nur serverseitig.
8. Wann kommt die SaaS, und braucht sie die Browser-Vorschau per Wasm, oder reicht serverseitig erzeugtes GLB?
