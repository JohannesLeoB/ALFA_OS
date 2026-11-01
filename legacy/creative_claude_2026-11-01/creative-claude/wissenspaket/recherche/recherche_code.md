# Recherche: Code-Bausteine für das Küchen-Planungssystem (Fusion → eigene App/SaaS)

Stand 31.10.2026. **Methode:** Versionen, Lizenzen und Release-Daten über die PyPI-, npm- und crates-APIs abgefragt; die letzte Aktivität stammt aus dem letzten Commit eines flachen Git-Klons. Funktionen wurden, wo angegeben, im Quelltext oder in der offiziellen Doku nachgeprüft. Die Codebeispiele in 1, 2, 3, 4, 5, 6, 7 und 8 liefen lokal mit Python 3.13 (build123d 0.13.0, ezdxf 1.4.5, packingsolver 0.1.1252, ortools 9.15, segno 1.6.6, reportlab 5.1.0, trimesh 5.2.0 + python-fcl, pydantic 2.14.2, ifcopenshell 0.9.0.post1, mcp 2.3.0, typst 0.15.0).
**Kennzeichnung:** *[unsicher]* steht bei Aussagen, die ich nur aus Drittquellen oder gar nicht verifizieren konnte.

---

## 1. CAD-Kernel ohne Fusion

| Projekt | Lizenz | Stand | Kann / Grenzen |
|---|---|---|---|
| **OpenCascade (OCCT)** | LGPL-2.1 + „Open CASCADE Exception 1.0“ | 8.0.1 (Tag); 8.0.0 seit 05/2026; Commit 2026-10-20 | B-Rep-Kern: Booleans, Fillets, HLR (`HLRBRep_Algo`), Schnitte, STEP/IGES/STL/glTF, `BRepExtrema`. 8.0 verlangt C++17 und bricht APIs (Exceptions, `LProp` wird zu `GeomProp`, Mesh-Plugins). Zum Ausgleich ist STEP-I/O jetzt pro Instanz threadsicher; IGES-Lesen ist es weiterhin nicht. |
| **OCP** (`cadquery-ocp`) | Apache-2.0 (Bindings) + OCCT-LGPL | 8.0.1.1.0 (2026-10-05) | pybind11-Bindings für OCCT 8.0.1. Wheels gibt es für macOS arm64/x86, Linux und Windows. Basis für CadQuery und build123d. |
| **build123d** | Apache-2.0 | 0.13.0 (2026-09-21); Commit 2026-10-30 | Pythonische API: `project_to_viewport` (HLR, sichtbare und verdeckte Kanten), `section`, `ExportDXF`/`ExportSVG` mit Layern (intern ezdxf), `drafting` (`DimensionLine`, `TechnicalDrawing`), `export_step/stl/gltf/obj/brep`, `pack`. Noch 0.x, deshalb die Version pinnen. IGES nur über OCP (`IGESControl_Writer`). |
| **CadQuery** | Apache-2.0 | 2.8.0 (2026-06-21); Commit 2026-10-24 | Fluent-/Workplane-API, große Community. Für neuen Code finde ich build123d lesbarer (Geschmacksfrage). |
| pythonocc-core | LGPL-3.0 | Commit 2026-10-14; Verteilung über conda (PyPI veraltet) | SWIG-Alternative zu OCP. Mit OCP gibt es keinen Grund, sie zusätzlich zu nutzen. |
| **OCCTSwift** | LGPL-2.1 | 3.0.0, ~15 Sterne | Swift-Wrapper für OCCT 8 (SPM + vorgebautes xcframework, macOS 12+/iOS 15+ arm64). Laut README gibt es HLR, Dimensionen, STEP und glTF. **Sehr junges Ein-Personen-Projekt** *[Reife unsicher]*. Für ALFA OS beobachten, nicht darauf bauen. |
| FreeCAD als Bibliothek | LGPL-2.1+ | 1.1.4 stabil; 26.3-RC (neues Versionsschema) | Headless über `FreeCADCmd script.py` oder `import FreeCAD` (mit `sys.path`). Part, Draft und BIM laufen ohne GUI, ViewProvider nicht. Ob TechDraw headless läuft, sagt die Doku nicht *[unsicher]*. Schwergewichtig als Server-Abhängigkeit. |
| Onshape-API | proprietär, Cloud | REST + FeatureScript | Kontingent: 2.500 (Free/Standard), 5.000 (Professional) bzw. 10.000 (Enterprise) API-Calls pro User und **Jahr**, dazu 429-Ratelimits. Für SaaS-Backends zu knapp und ein Lock-in. Nur als Austauschziel interessant. |
| replicad | MIT | 1.2.0 (2026-10-23) | OCCT als WASM im Browser. Option für clientseitige Geometrie im Web-SaaS. |
| **three-cad-viewer** | MIT | 5.1.3 (2026-10-12); Commit 2026-10-31 | three.js-Viewer für tessellierte B-Reps: Bauteilbaum, Clipping, Kantenanzeige, `addPart/updatePart`. Läuft im Web und in einem WKWebView. |
| ocp_vscode / ocp-tessellate | Apache-2.0 | 4.2.0 / 3.6.3 (Okt. 2026) | Dev-Viewer in VS Code. `ocp-tessellate` erzeugt das Format für three-cad-viewer. |

```python
# [lokal ausgeführt] Korpus -> STEP/STL -> Vorderansicht per HLR -> DXF/SVG mit Layern
from build123d import Box, Pos, Compound, export_step, ExportDXF, ExportSVG, LineType, Unit
B, T, H, s = 600, 560, 720, 19
korpus = Compound([Pos(-B/2+s/2, 0, H/2)*Box(s, T, H), Pos(B/2-s/2, 0, H/2)*Box(s, T, H),
                   Pos(0, 0, s/2)*Box(B-2*s, T, s)])
export_step(korpus, "korpus.step")
sichtbar, verdeckt = korpus.project_to_viewport((0, -5000, H/2), viewport_up=(0, 0, 1))
dxf = ExportDXF(unit=Unit.MM)
dxf.add_layer("SICHTBAR"); dxf.add_layer("VERDECKT", line_type=LineType.ISO_DASH)
dxf.add_shape(sichtbar, layer="SICHTBAR"); dxf.add_shape(verdeckt, layer="VERDECKT")
dxf.write("vorderansicht.dxf")      # analog ExportSVG(...).write("vorderansicht.svg")
```
Quellen: github.com/Open-Cascade-SAS/OCCT · occt3d.com/dev/content/open-cascade-technology-800-release · pypi.org/project/build123d · github.com/gumyr/build123d · github.com/CadQuery/OCP · github.com/gsdali/OCCTSwift · wiki.freecad.org/Headless_FreeCAD · onshape-public.github.io/docs/auth/limits · github.com/bernhard-42/three-cad-viewer · npmjs.com/package/replicad

---

## 2. 2D, Zeichnung und Planausgabe

| Projekt | Lizenz | Stand | Kann / Grenzen |
|---|---|---|---|
| **ezdxf** | MIT | 1.4.5 (2026-10-16), Python ≥ 3.11 | Liest und schreibt DXF R12–R2018 (AC1009–AC1032). Layer, Linientypen, Blöcke, Layouts/Papierbereich, Bemaßung (linear, ausgerichtet, Ketten, Radius, Durchmesser, Winkel; mit `dim.render()`). Das Add-on `drawing` rendert nach SVG und PDF (Backends: SVG, PyMuPDF, matplotlib). Das Add-on `odafc` ruft für DWG den ODA File Converter auf. |
| ODA File Converter | Freeware, proprietär | aktuell; macOS ≥ 13 (arm64/x64), Linux x64, Win | Konvertiert DWG ⇄ DXF. **Nutzungsbedingungen stehen nicht auf der Downloadseite.** Ob er sich in SaaS einbinden oder weitergeben lässt, ist ungeklärt *[unsicher, vor Produktivnutzung mit ODA klären]*. Unter macOS lässt sich das GUI-Fenster nicht unterdrücken, unter Linux nur mit xvfb. Laut ezdxf-Doku ist das Starten eines externen Programms ein Sicherheitsrisiko. |
| LibreDWG | **GPL-3.0+** | Commit 2026-10-31, Tags 0.14.x | Laut README: Der Reader liest alle Versionen. Der Writer reicht für alles außer R2007, **beim Schreiben von R2010–R2018 entstehen noch CRC-Fehler**. GPL und dieser Reifegrad schließen die Bibliothek für die App aus. |
| cairosvg | LGPL-3.0+ | 2.9.1 (2026-09) | SVG → PDF/PNG, braucht die native Bibliothek cairo. |
| svglib + reportlab | LGPL-3.0+ / BSD | 2.3.2 / 5.1.0 (Okt. 2026) | SVG → ReportLab-Drawing → PDF. ReportLab eignet sich auch für Etiketten. |
| WeasyPrint | BSD-3 | 70.0 (2026-09) | HTML/CSS → PDF mit CSS Paged Media (`@page`, Randboxen, Seitenzähler). Kein JavaScript. |
| Paged.js | MIT | npm 0.4.3 (**2023**); Repo aktiv (2026-10) | Paged-Media-Polyfill im Browser, PDF über Chromium/Puppeteer. Seit drei Jahren kein Release, deshalb *[Reife unsicher]*. |
| Jinja2 / Handlebars / Mustache | BSD / MIT / MIT | 3.1.6 / 4.7.10 / 4.2.0 (2021) | Templates für Planköpfe. Mustache ist logikfrei und lässt sich sprachübergreifend (Swift/Python/JS) nutzen. |
| **Typst** | Apache-2.0 | CLI 0.15.1; `typst` (Python) 0.15.0 | Satzsystem: schnell, ein einzelnes Binary, PDF/SVG/PNG, PDF/A. Daten kommen über `sys_inputs`. Gut für Planköpfe, Planpakete, Stücklisten und Etiketten. |

```python
# [lokal ausgeführt] ezdxf: Studio-Layer + Bemaßung
import ezdxf
doc = ezdxf.new("R2018", setup=True)               # setup=True erzeugt Dimstyle "EZDXF"
doc.layers.add("KORPUS", color=7); doc.layers.add("BEMASSUNG", color=1)
msp = doc.modelspace()
msp.add_lwpolyline([(0,0),(600,0),(600,720),(0,720)], close=True, dxfattribs={"layer": "KORPUS"})
msp.add_linear_dim(base=(0,-80), p1=(0,0), p2=(600,0), dimstyle="EZDXF",
                   dxfattribs={"layer": "BEMASSUNG"}).render()
doc.saveas("ansicht.dxf")
# DWG optional: from ezdxf.addons import odafc; odafc.export_dwg(doc, "ansicht.dwg", version="R2018")
```
```python
# [lokal ausgeführt] Typst-Plankopf: Daten aus Python, SVG-Ansicht eingebunden
#  plan.typ:  #let d = json(bytes(sys.inputs.plan))
#             #set page(paper: "a3", flipped: true, margin: 10mm)
#             #image("vorderansicht.svg", width: 60mm)   // 600 mm bei 1:10 -> Breite explizit setzen!
#             #place(bottom + right, table(columns: (40mm, 60mm), [Projekt], [#d.projekt], [Maßstab], [#d.massstab]))
import json, typst
typst.compile("plan.typ", output="plan.pdf",
              sys_inputs={"plan": json.dumps({"projekt": "Runde 1", "massstab": "1:10"})})
```
Quellen: ezdxf.readthedocs.io (introduction, addons/odafc, tutorials/linear_dimension) · opendesign.com/guestfiles/oda_file_converter · github.com/LibreDWG/libredwg (README) · pypi.org/project/weasyprint · github.com/pagedjs/pagedjs · github.com/typst/typst · github.com/messense/typst-py

---

## 3. Zuschnittoptimierung

| Projekt | Lizenz | Stand | Kann / Grenzen |
|---|---|---|---|
| **OpenCutList** (L'Air du Bois) | **GPL-3.0** | v7.1.0; Commit 2026-10-19 | SketchUp-Extension in Ruby mit C++-Bibliotheken. Laut i18n und Quelltext: Stückliste; Zuschnittpläne mit „Blade Thickness“ (Kerf), „Trimming“ (Besäumung), Maserrichtung pro Teil („Ignore grain orientation“) und Stapelrichtung; Kantenbelegung (Fertigmaß wird um die Kantendicke reduziert, Kantenbedarf als 1D-Liste); Etiketten; Kosten- und Gewichtsberichte; Export als CSV/XLSX; Zuschnittplan-Geometrie als **SVG/DXF** (Layer oder Layer + Blöcke); Teileprojektion als SVG/DXF; Nesting. Die Engine „Packy“ ist ein Fork von **fontanf/packingsolver**, dazu kommt Clipper2. → **Fachliche Referenz** für das Datenmodell. Wegen der GPL nicht in die App einbauen. |
| **PackingSolver** | **MIT** | PyPI 0.1.1252 (2026-10-31), aktiv; C++, CLI, Python, Web | Problemtyp `rectangleguillotine`: Stufenzahl, Schnitttypen, Schnittbreite (Kerf), Besäumung je Kante, Fehlerstellen, Drehung pro Teil (`oriented=True` heißt Maserrichtung fix), Stapel, Mindest- und Maximalabstände von Schnitten, Reststück-Ziel (`BinPackingWithLeftovers`), variable Plattengrößen. Daneben `irregular` (Nesting), `onedimensional` (Kanten, Leisten) und 3D. Ausgabe: Schnittbaum als CSV/JSON. → **Erste Wahl.** Versionsschema 0.1.x, deshalb pinnen. |
| rectpack | Apache-2.0 | 0.2.2 (**2021**, inaktiv) | MaxRects-, Skyline- und Guillotine-Heuristiken, Drehung an/aus. Kein Kerf und keine Besäumung (Behelf: Teile um den Kerf aufblasen). Nur für schnelle Tests. |
| OR-Tools (CP-SAT) | Apache-2.0 | 9.15 (2026-01) | `add_no_overlap_2d` mit Beispiel `knapsack_2d_sat.py`. **Guillotine-Bedingungen sind nicht eingebaut** und müssten selbst modelliert werden, das ist aufwendig. Besser für Layout (Abschnitt 6). |
| opcut | GPL-3.0 | 0.4.16 (2025-03) | Guillotine-Cutting-Stock mit Web-UI. GPL. |
| SVGnest / Deepnest(-next) | MIT / MIT | SVGnest: letzter Commit 2019; deepnest-next v1.5.6, Commit 2026-10-18 | Freiform-Nesting (CNC) per genetischem Algorithmus und No-Fit-Polygon. Electron-App, eine stabile Bibliotheks-API habe ich nicht gefunden *[unsicher]*. Für rechteckige Platten unnötig. |

**Fachliche Abbildung:** Kerf heißt `set_cut_thickness`. Besäumung heißt `trims=` an der Platte. Maserrichtung heißt `oriented=True`. Kanten: Zuschnittmaß = Fertigmaß − Kantendicke (+ Fräszugabe nach Studio- bzw. Werkstattregel). Kanten-Meter werden als 1D-Problem gerechnet. „Two-stage“ bzw. „three-stage“ bezeichnet, wie viele Schnittrichtungswechsel die Plattensäge machen darf.
**Literatur:** *Multistage Cutting Stock Problems of Two and More Dimensions*, Operations Research 13(1):94–120, 1965 (mehrstufiger Guillotine-Zuschnitt, Spaltengenerierung). Typologie der Zuschnitt- und Packprobleme, EJOR 183(3):1109–1130, 2007. Survey 2D-Packing, EJOR 141(2):241–252, 2002. ROADEF/EURO Challenge 2018 (3-stufiger Glaszuschnitt mit Defekten; PackingSolver hat dafür einen eigenen Schnitttyp `roadef2018`).

```python
# [lokal ausgeführt] Ergebnis: 1 Platte, 24,3 % Verschnitt
import packingsolver.rectangleguillotine as psg
ib = psg.InstanceBuilder()
ib.set_objective(psg.Objective.BinPackingWithLeftovers)
ib.set_cut_thickness(4)                                        # Sägeblatt 4 mm
ib.add_bin_type(2800, 2070, copies=10, trims={"left_trim": 10, "right_trim": 10,
                                               "bottom_trim": 10, "top_trim": 10})
ib.add_item_type(720, 560, oriented=True, copies=4)            # Seiten, Maserrichtung fix
ib.add_item_type(562, 560, copies=6)                           # Böden, drehbar
p = psg.OptimizeParameters(); p.time_limit = 3; p.verbosity_level = 0
sol = psg.optimize(ib.build(), p).solution
print(sol.number_of_bins(), sol.waste_percentage())
sol.write("schnittplan.csv")   # PLATE_ID,COPIES,NODE_ID,X,Y,WIDTH,HEIGHT,TYPE,CUT,PARENT
```
Quellen: github.com/lairdubois/lairdubois-opencutlist-sketchup-extension (en.yml, Packy/extern/CMakeLists.txt) · docs.opencutlist.org · github.com/fontanf/packingsolver · fontanf.github.io/packingsolver · github.com/secnot/rectpack · github.com/google/or-tools/blob/stable/examples/python/knapsack_2d_sat.py · github.com/deepnest-next/deepnest · pubsonline.informs.org/doi/10.1287/opre.13.1.94

---

## 4. Etiketten, QR und Data Matrix

| Projekt | Lizenz | Stand | Kann / Grenzen |
|---|---|---|---|
| **segno** | BSD-3 | 1.6.6 (2025-03); Commit 2026-07 | QR und Micro-QR, ohne Abhängigkeiten. Ausgabe SVG/PNG/PDF/EPS. **Kein Data Matrix.** |
| qrcode | BSD | 8.2 (2025-05) | QR, mit Pillow. |
| **reportlab** | BSD | 5.1.0 (2026-10) | Etiketten-PDF. Barcodes: QR, **ECC200DataMatrix (reines Python)**, Code128 u. a. (Module im Wheel geprüft). |
| zxing-cpp | Apache-2.0 | 3.1.1 (2026-07) | Liest und schreibt viele Formate inkl. Data Matrix (Writer-Backend zint). Wrapper für Python, **iOS/Swift**, WASM u. a. |
| pylibdmtx / treepoem | MIT / MIT | 0.1.10 (**2022**) / 3.29.0 (2026-09) | pylibdmtx braucht libdmtx. treepoem braucht Ghostscript und nutzt BWIPP (MIT). |
| bwip-js | MIT | 4.11.4 (2026-08) | JS-Barcodes (QR, Data Matrix) für Web und Node. |
| ZPL (Zebra) | – | – | ZPL lässt sich einfach als Text erzeugen: `^XA … ^XZ`, `^BQ` (QR), `^BX…,200` (Data Matrix ECC200), `^CI28` (UTF-8). Python-Paket `zpl` ist **AGPL-3.0**, deshalb meiden. `simple-zpl2` (MIT) ist seit 2020 inaktiv. `zebrafy` (LGPL-3) wandelt PDF/Bild in ZPL. |
| Swift/CoreImage | Apple | – | `CIQRCodeGenerator`, Aztec, PDF417 und Code128 sind eingebaut. Einen Data-Matrix-Generator hat CoreImage nach meinem Stand nicht *[unsicher]*. Dafür zxing-cpp nehmen oder den Code serverseitig erzeugen. |

```python
# [lokal ausgeführt] QR (SVG), Data Matrix im PDF-Etikett, ZPL als String
import segno
from reportlab.pdfgen import canvas; from reportlab.lib.units import mm
from reportlab.graphics.barcode import createBarcodeDrawing; from reportlab.graphics import renderPDF
segno.make("K12-SEITE-L|P-2026-0815|720x560x19", error="m").save("teil.svg", scale=4, border=2)
c = canvas.Canvas("label.pdf", pagesize=(100*mm, 50*mm))
c.setFont("Helvetica-Bold", 10); c.drawString(4*mm, 42*mm, "K12 Seite links  720 x 560 x 19")
renderPDF.draw(createBarcodeDrawing("ECC200DataMatrix", value="K12-SEITE-L"), c, 70*mm, 10*mm)
c.save()
zpl = ("^XA^CI28^FO30,30^A0N,40,40^FDK12 Seite links^FS^FO30,90^A0N,30,30^FD720x560x19 Kante v,h^FS"
       "^FO600,30^BQN,2,5^FDMA,K12-SEITE-L^FS^FO450,30^BXN,6,200^FDK12-SEITE-L^FS^XZ")
```
Quellen: pypi.org/project/segno · pypi.org/project/reportlab · pypi.org/project/zxing-cpp · github.com/zxing-cpp/zxing-cpp · github.com/metafloor/bwip-js · zebra.com (ZPL II Programming Guide, zpl-zbi2-pm-en.pdf) · pypi.org/project/zpl

---

## 5. Kollisionserkennung und Geometrieprüfung

| Ansatz | Lizenz | Stand | Kann / Grenzen |
|---|---|---|---|
| **AABB** (selbst geschrieben) | – | – | Korpusse sind fast immer achsparallel. Ein Box-Test mit Toleranz ist schnell, erklärbar und für Regelprüfungen ausreichend. Türaufschlag, Auszüge und Gerätefreiräume lassen sich als zusätzliche „Freiraum-Boxen“ modellieren. Grenzen: Schrägen, Eckschränke, gedrehte Elemente. |
| **OCCT** über OCP/build123d | LGPL / Apache | 8.0.1 | Exakt auf B-Rep: `BRepAlgoAPI_Common` (Überschneidungsvolumen; in build123d `a & b`), `BRepExtrema_DistShapeShape` (Mindestabstand; `a.distance_to(b)`), `BRepAlgoAPI_Section`. Langsamer, deshalb für Grenzfälle oder als Endprüfung. |
| **trimesh** + **python-fcl** | MIT / BSD-3 | 5.2.0 (2026-10) / 0.7.0.11 (2026-04) | Mesh-Kollision: `CollisionManager.add_object`, `in_collision_internal`, `min_distance_internal` (fcl ist Pflicht). Sinnvoll für importierte Meshes (Geräte-STL, Fremdmodelle). |

```python
# [lokal ausgeführt] AABB-Regel + exakte OCCT-Prüfung + Mesh-Variante
def ueberlappt(a, b, tol=0.0):   # a,b = (x0,y0,z0,x1,y1,z1) in mm
    return all(a[i] < b[i+3]-tol and b[i] < a[i+3]-tol for i in range(3))
from build123d import Box, Pos
u1, u2 = Pos(300,280,360)*Box(600,560,720), Pos(890,280,360)*Box(600,560,720)
print((u1 & u2).volume)          # 4032000.0 mm³ -> 10 mm Überlappung
import trimesh
cm = trimesh.collision.CollisionManager()
cm.add_object("U1", trimesh.creation.box((600,560,720)), trimesh.transformations.translation_matrix((300,280,360)))
cm.add_object("U2", trimesh.creation.box((600,560,720)), trimesh.transformations.translation_matrix((890,280,360)))
print(cm.in_collision_internal(return_names=True))   # (True, {('U1','U2')})
```
Quellen: dev.opencascade.org (Reference BRepAlgoAPI/BRepExtrema) · github.com/mikedh/trimesh (trimesh/collision.py) · github.com/BerkeleyAutomation/python-fcl

---

## 6. Constraints, Layout und parametrische Möbel (Open Source)

**OR-Tools CP-SAT** (Apache-2.0, 9.15) eignet sich für die Modulaufteilung: ganzzahlige Breiten, Pflichtmodule (Spüle, Geschirrspüler, Herd), Passleisten links und rechts, Symmetrie, Ecken und Fixpunkte (Fenster, Wasseranschluss). Für eine einzelne gerade Wand würde auch eine dynamische Programmierung (Rucksack) reichen. CP-SAT lohnt sich, sobald mehrere Wände, Ecken und Gerätepositionen gekoppelt sind.

```python
# [lokal ausgeführt] Ergebnis: OPTIMAL {450:1, 600:3, 900:1}, Passleisten 5/15 mm
from ortools.sat.python import cp_model
WAND, BREITEN = 3170, [300, 400, 450, 500, 600, 800, 900]
m = cp_model.CpModel()
n = {b: m.new_int_var(0, WAND // b, f"n{b}") for b in BREITEN}
pl, pr = m.new_int_var(0, 60, "pass_l"), m.new_int_var(0, 60, "pass_r")
m.add(sum(b * n[b] for b in BREITEN) + pl + pr == WAND)
m.add(n[600] >= 1)                                   # Spülenschrank
m.add(pl - pr <= 10); m.add(pr - pl <= 10)           # annähernd symmetrisch
m.minimize(10 * sum(n.values()) + pl + pr)           # wenige Module, kleine Passleisten
s = cp_model.CpSolver(); s.parameters.max_time_in_seconds = 2
st = s.solve(m); print(s.status_name(st), {b: s.value(v) for b, v in n.items() if s.value(v)})
```
Für die Reihenfolge der Module braucht man zusätzlich Positionsvariablen mit `add_no_overlap` über Intervalle oder eine Sequenz pro Slot.

| Parametrische Möbel (real existierend) | Lizenz | Stand | Inhalt |
|---|---|---|---|
| **FreeCAD Woodworking Workbench** | MIT | Tag 4.0; Commit 2026-10-06 | `magicStart` (Korpus-Grundstruktur), `magicDowels` (Dübel, Minifix, Schrauben), `magicDriller`, `getDimensions` (Zuschnittliste, Kosten, Gewicht), `sheet2export` (CSV, JSON, HTML, Markdown). Gutes Ideenreservoir. Python-Makros auf FreeCAD. |
| **Home Builder 5** (Blender-Add-on) | **GPL-3.0** | Commit 2026-10-30 | Grundrisse, parametrische Schränke (Bauweisen, Beschläge), technische Zeichnungen und CNC-Export (laut Hackster-Artikel). GPL, deshalb nur als Referenz. |
| bd_warehouse | Apache-2.0 | 0.4.0 (2026-10) | Parametrische Normteile (Schrauben, Lager …) für build123d. |
| „OpenCabinet“ | – | – | **Kein belastbares Projekt gefunden.** Nicht zitieren. Furnimatic und MakraCab (Blender) tauchen nur als kommerzielle Add-ons auf *[nicht geprüft]*. |

Quellen: developers.google.com/optimization (CP-SAT) · github.com/dprojects/Woodworking · github.com/CreativeDesigner3D/home_builder_5 · hackster.io (Home Builder 5.1) · pypi.org/project/bd-warehouse

---

## 7. Templates und Datenformate

| Baustein | Lizenz | Stand | Rolle |
|---|---|---|---|
| **Pydantic v2** | MIT | 2.14.2 (2026-10-29) | Fachmodelle als Quelle der Wahrheit. `Model.model_json_schema()` liefert JSON Schema (Draft 2020-12). Das erzeugte Dict enthält **kein** `$schema`-Feld, das muss man selbst setzen (geprüft). |
| JSON Schema 2020-12 | offen | – | Vertrag zwischen Server, Swift-App, MCP-Tools (`inputSchema`) und Templates. |
| quicktype | Apache-2.0 | 26.0.0 (2026-07) | JSON Schema → Swift `Codable` (und TypeScript), damit ALFA OS dieselben Typen nutzt. |
| GRDB.swift | MIT | v7.11.1 | SQLite in ALFA OS: Projekte und Module relational, Parameter als JSON-Spalte. |
| **IfcOpenShell** | LGPL-3.0+ | 0.9.0.post1 (2026-10-15) | BIM-Austausch. API-Stil seit 0.8: `ifcopenshell.api.<modul>.<funktion>(model, ...)`. **`IfcFurnishingElement` ist in IFC4.3 ein ONEOF-Supertyp**, instanziieren muss man `IfcFurniture` oder `IfcSystemFurnitureElement`. `IfcFurnitureTypeEnum` hat keinen Küchenschrank (Werte: BED, CHAIR, DESK, FILECABINET, SHELF, SOFA, TABLE, TECHNICALCABINET, USERDEFINED, NOTDEFINED), deshalb `USERDEFINED` + `ObjectType`. |

```python
# [lokal ausgeführt] Pydantic -> JSON Schema; IFC-Export eines Moduls
from typing import Literal
from pydantic import BaseModel, Field
class Modul(BaseModel):
    id: str
    typ: Literal["unterschrank", "oberschrank", "hochschrank"]
    breite_mm: int = Field(ge=150, le=1200)
    hoehe_mm: int = 720
    front: Literal["tuer", "schublade", "klappe", "offen"] = "tuer"
schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", **Modul.model_json_schema()}

import ifcopenshell.api.project, ifcopenshell.api.root, ifcopenshell.api.geometry, ifcopenshell.api.context
m = ifcopenshell.api.project.create_file(version="IFC4")
# ... IfcProject/Units/Context/Site/Building/Storey wie in der IfcOpenShell-Doku (code_examples) ...
us = ifcopenshell.api.root.create_entity(m, ifc_class="IfcFurniture", name="U1 Spüle 600",
                                         predefined_type="USERDEFINED")
us.ObjectType = "KITCHENBASECABINET"
# rep = ifcopenshell.api.geometry.add_mesh_representation(m, context=body, vertices=v, faces=f)
# ifcopenshell.api.geometry.assign_representation(m, product=us, representation=rep)
```
Quellen: docs.pydantic.dev · json-schema.org · npmjs.com/package/quicktype · github.com/groue/GRDB.swift · docs.ifcopenshell.org (code_examples, geometry_creation) · ifc43-docs.standards.buildingsmart.org (IfcFurnishingElement, IfcFurnitureTypeEnum)

---

## 8. MCP und Agent Skills

| Baustein | Lizenz | Stand | Hinweise |
|---|---|---|---|
| **MCP Python SDK** (`mcp`) | MIT; Projekt wechselt zu Apache-2.0 | 2.3.0 (2026-10-02), Python ≥ 3.11 | **v2-API:** `from mcp.server import MCPServer` (früher `FastMCP`). Das Schema entsteht aus den Type-Hints. Transporte: stdio, Streamable HTTP, SSE. Mit `mcp dev` (Inspector). |
| MCP TypeScript SDK | MIT/Apache-2.0 | `@modelcontextprotocol/sdk` 1.32.2 (2026-10-23) | Für einen späteren Web- oder Node-Server. |
| **MCP Swift SDK** (offiziell) | MIT/Apache-2.0 | 0.12.1; Commit 2026-10-31; Swift 6.0+ | Client und Server, Spec 2025-11-25, Stdio- und HTTP-Transport, OAuth. Die API ist Low-Level (`withMethodHandler(ListTools.self)`, `CallTool`). Damit kann ALFA OS selbst MCP-Client oder MCP-Server sein. |
| **Autodesk Fusion MCP** | proprietär | Blog vom 02.07.2026 | Lokaler Server in Fusion Desktop, arbeitet auf der laufenden Session. Laut Drittquelle aktiviert man ihn unter Preferences > General > API, er antwortet unter `http://127.0.0.1:27182/mcp`, Status GA *[Details unsicher]*. Daneben gibt es den **Fusion Data MCP** (Cloud: Hubs, Projekte, Ordner, Rechte; Auth-Flow). |
| freecad-mcp | MIT | 0.1.28 (2026-10-25) | FreeCAD-Add-on mit RPC. Tools u. a. `execute_code`, `execute_code_headless` (freecadcmd), `get_view` (Screenshot), `create_object`, `insert_part_from_library`. |
| mcp-for-blender (ex blender-mcp) | MIT | 2.0.0 (2026-09-16) | Blender-Steuerung über ein Add-on-Socket. |
| build123d-mcp | Apache-2.0 | 0.3.91 (2026-10-15), ~60 Sterne | Persistente build123d-Session, Render (PNG/SVG/DXF), Messen, Export STEP/STL/DXF, Snapshots. Ein-Personen-Projekt. Gutes Vorbild für einen eigenen Server. |
| cadquery-mcp | Apache-2.0 | 0.1.0 (2026-01) | Liegt laut PyPI in cadquery-contrib. Noch früh *[Reife unsicher]*. |
| **Agent Skills** (agentskills.io) | offener Standard (von Anthropic initiiert) | – | Ordner mit `SKILL.md` (YAML-Frontmatter: `name` ≤ 64 Zeichen, Kleinbuchstaben und Bindestriche, muss dem Ordnernamen entsprechen; `description` ≤ 1024 Zeichen; optional `license`, `compatibility`, `metadata`, `allowed-tools` [experimentell]), dazu `scripts/`, `references/`, `assets/`. Progressive Disclosure: zuerst nur Metadaten, `SKILL.md` unter 500 Zeilen. Validierung mit `skills-ref validate`. **Portabel ist das Format, nicht die Laufzeit:** Skripte brauchen die passende Python-Umgebung und die MCP-Tools. Deshalb Werkzeuge über MCP anbinden und den Skill nur den Ablauf beschreiben lassen. |

```python
# [lokal ausgeführt: Import + Registrierung] Werkzeug-Server, Python SDK v2
from mcp.server import MCPServer
mcp = MCPServer("kuechen-werkzeuge")

@mcp.tool()
def modulaufteilung(wandlaenge_mm: int, breiten_mm: list[int]) -> dict:
    """Teilt eine Wandlänge per CP-SAT in Standardmodule auf."""
    ...  # Code aus Abschnitt 6
# Start: `uv run mcp dev server.py` oder `mcp run server.py --transport streamable-http`
```
```markdown
---
name: kuechen-plan
description: Erstellt aus einem Küchenprojekt (JSON nach Studio-Schema) Ansichten, Zuschnitt und Etiketten im Studio-Zeichnungsstil. Verwenden bei Küchenplanung, Werkplänen, Schnittlisten.
compatibility: Benötigt MCP-Server "kuechen-werkzeuge" (Python ≥ 3.11)
---
```
Quellen: github.com/modelcontextprotocol/python-sdk · py.sdk.modelcontextprotocol.io · github.com/modelcontextprotocol/swift-sdk · npmjs.com/package/@modelcontextprotocol/sdk · autodesk.com/products/fusion-360/blog/introducing-the-autodesk-fusion-data-mcp-server · developersdigest.tech/mcp-servers/autodesk-fusion-mcp (Drittquelle) · github.com/neka-nat/freecad-mcp · github.com/pzfreo/build123d-mcp · agentskills.io/specification · github.com/anthropics/skills

---

## Lizenz-Ampel (für App-Auslieferung und SaaS)

- **Unkritisch (MIT/BSD/Apache):** build123d, CadQuery, OCP-Bindings, ezdxf, PackingSolver, OR-Tools, segno, reportlab, zxing-cpp, trimesh, python-fcl, Pydantic, Typst, three-cad-viewer, MCP-SDKs, GRDB, Woodworking-WB.
- **LGPL (dynamisch linken, Hinweis- und Austauschpflicht):** OCCT (mit Exception für Header), FreeCAD, IfcOpenShell, cairosvg, svglib, OCCTSwift. Serverseitig ist das unproblematisch. Bündelt man es in die signierte macOS-App, muss der Nutzer die Bibliothek austauschen können *[rechtlich prüfen]*.
- **GPL/AGPL (nicht einbinden, nur als Referenz):** OpenCutList, Home Builder 5, LibreDWG, opcut, `zpl` (AGPL wirkt auch bei SaaS).
- **Proprietär oder ungeklärt:** ODA File Converter (Bedingungen klären), Onshape (Call-Kontingent), Fusion MCP (Fusion-Lizenz nötig).

---

## Empfohlener Tech-Stack je Schicht

| Schicht | Empfehlung | Begründung |
|---|---|---|
| **Datenmodell** | Pydantic-Modelle (Projekt → Raum → Wand → Modul → Teil → Kante/Beschlag) als Quelle. Daraus JSON Schema 2020-12, mit quicktype Swift-`Codable`, gespeichert in GRDB (App) bzw. als serverseitiger Store *[Server-DB nicht recherchiert]* | Ein Schema für Server, App, MCP-`inputSchema` und Templates. Versionierbar und validierbar. Fusion wird zu einem von mehreren „Renderern“ des Modells. |
| **Geometrie** | build123d auf OCP/OCCT 8 (Python, serverseitig bzw. als lokaler Sidecar der Mac-App). Viewer: three-cad-viewer (Web und WKWebView) über ocp-tessellate | Freie Lizenzen, STEP und HLR an Bord, macOS-arm64-Wheels. Swift-nativer Kern (OCCTSwift) ist zu unreif, deshalb erst beobachten. |
| **2D/Plan** | HLR (`project_to_viewport`) und Schnitte (`section`) mit build123d, danach **ezdxf** (DXF R2018, Studio-Layer, Bemaßung) und SVG. **Typst** für Plankopf, Planpaket und PDF. DWG nur bei Bedarf über ODA File Converter in einem isolierten Linux-Job | Ein Datenweg für DXF und PDF. Typst ist reproduzierbar und schnell und hat eine Python-Bindung mit `sys_inputs`. DWG-Lizenzfrage bleibt offen. |
| **Zuschnitt** | **PackingSolver** `rectangleguillotine` (Kerf, Besäumung, Maserrichtung, Reststücke), Kanten als `onedimensional`. Darstellung: CSV-Baum → SVG/DXF über ezdxf | MIT, aktiv, praxisnah. Dieselbe Engine (als Fork) steckt in OpenCutList. Funktionsumfang von OpenCutList als Checkliste nutzen. |
| **Labels** | segno (QR) + reportlab (Data Matrix, PDF) oder Typst-Etikettenvorlage; ZPL als Textvorlage; in Swift QR über CoreImage | Pure Python, keine AGPL. Teile-ID als einziger Barcode-Inhalt, Details aus der DB. |
| **Prüfung** | Regelwerk auf AABB-Basis (inkl. Freiraum-Boxen für Türaufschlag, Auszug, Geräte). Exakte OCCT-Prüfung (`&`-Volumen, `distance_to`) für Grenzfälle. trimesh/fcl nur für importierte Meshes | Schnell und für den Planer erklärbar („Tür U3 schlägt an Griff H1 an“). Exaktheit nur dort, wo sie nötig ist. |
| **Layout** | OR-Tools CP-SAT für Modulaufteilung und Wandbelegung | Ganzzahlig, schnell, Fixpunkte und Symmetrien lassen sich leicht ausdrücken. |
| **MCP/Skills** | Ein Python-MCP-Server „kuechen-werkzeuge“ (SDK v2, `MCPServer`) mit fachlichen Tools (`modulaufteilung`, `korpus_bauen`, `ansicht_dxf`, `zuschnitt`, `etiketten`, `pruefen`). Fusion MCP läuft in der Übergangszeit parallel. ALFA OS spricht über das Swift SDK. Workflows und Zeichenstil als Agent Skill (`SKILL.md` + `references/zeichenstil.md`) | Werkzeuge sind deterministischer Code, Claude orchestriert. Die Skills bleiben portabel, weil sie nur Abläufe beschreiben. |
| **BIM (später)** | IfcOpenShell: `IfcFurniture` USERDEFINED + Psets | Austausch mit Architekten, ohne eigene Geometrie zu verlieren. |

## Was zuerst prototypen (Reihenfolge)

1. **Schema-Spike:** Pydantic-Modelle für Wand, Modul und Teil inkl. Kanten und Maserrichtung, daraus JSON Schema, mit quicktype Swift-Typen erzeugen und den Roundtrip über GRDB in ALFA OS prüfen. Ohne dieses Schema hängt alles Weitere an Fusion.
2. **Korpus-Generator in build123d:** Unterschrank-Parameter → Platten (Teileliste mit Fertig- und Zuschnittmaß) → STEP. Dasselbe Modul parallel über Fusion MCP bauen und vergleichen; das ist der Migrationsbeweis.
3. **Ansicht → Plan:** Vorderansicht und Draufsicht per HLR, ezdxf mit Studio-Layern und Bemaßung, Typst-Plankopf, PDF. An einer echten Studio-Zeichnung messen (Linienstärken, Strichart verdeckt, Maßstab 1:10/1:20).
4. **Zuschnitt + Etiketten:** Teileliste aus Schritt 2 → PackingSolver (Kerf 4, Besäumung 10, Maserrichtung) → Schnittplan-SVG und QR-Etiketten-PDF. Ergebnis gegen OpenCutList bzw. die Werkstatt prüfen.
5. **MCP-Server bündeln:** die Schritte 2–4 und die CP-SAT-Modulaufteilung als Tools, in Claude neben Fusion MCP testen. Danach den ersten Agent Skill schreiben.
6. **Prüfregeln (AABB):** Türaufschlag, Geräteabstände, Eckkollision. Erst danach exakte OCCT-Checks.

*Bewusst später:* DWG (Lizenz), IFC, Swift-nativer CAD-Kern, Web-SaaS mit replicad oder Server-Rendering.
