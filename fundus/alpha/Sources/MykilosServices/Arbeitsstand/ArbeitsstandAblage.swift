import Foundation
import MykilosKit

public enum ArbeitsstandEditor: String, CaseIterable, Sendable, Identifiable {
    case aufmass, plan, konfigurator, atelier, moodboard

    public var id: String { rawValue }

    public var folderName: String {
        switch self {
        case .aufmass:      "Aufmaße"
        case .plan:         "Pläne"
        case .konfigurator: "Konfigurationen"
        case .atelier:      "Atelier"
        case .moodboard:    "Moodboards"
        }
    }

    public var display: String {
        switch self {
        case .aufmass:      "Aufmaß"
        case .plan:         "Plan"
        case .konfigurator: "Konfigurator"
        case .atelier:      "Atelier"
        case .moodboard:    "Moodboard"
        }
    }

    public var fileName: String { "\(rawValue).json" }
}

public struct Arbeitsstand: Identifiable, Sendable, Equatable {
    public let id: String
    public let editor: ArbeitsstandEditor
    public let folder: URL
    public var projectNumber: String?
    public var title: String
    public var kuerzel: String
    public var geaendertAm: Date

    public var file: URL { folder.appendingPathComponent(editor.fileName) }

    public init(id: String, editor: ArbeitsstandEditor, folder: URL, projectNumber: String?,
                title: String, kuerzel: String, geaendertAm: Date) {
        self.id = id; self.editor = editor; self.folder = folder
        self.projectNumber = projectNumber; self.title = title
        self.kuerzel = kuerzel; self.geaendertAm = geaendertAm
    }

    public var beilagen: [URL] {
        let alle = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])) ?? []
        return alle.filter { $0.lastPathComponent != editor.fileName }.sorted { $0.path < $1.path }
    }
}

public struct ArbeitsstandAblage: Sendable {
    public static let folderName = "mykilOS Werkstatt"

    static let driveTeile = ["Geteilte Ablagen/MYKILOS Team/mykilOS",
                             "Shared drives/MYKILOS Team/mykilOS"]

    public let root: URL
    public let ausweich: URL
    public let imDrive: Bool

    public static let uebertragenOrdner = "_Übertragen"

    public init(driveWurzeln: [URL], ausweich: URL = DatenRoot.root()) {
        let lokal = ausweich.appendingPathComponent(Self.folderName, isDirectory: true)
        self.ausweich = lokal
        for root in driveWurzeln {
            for teil in Self.driveTeile {
                let kandidat = root.appendingPathComponent(teil, isDirectory: true)
                if FileManager.default.fileExists(atPath: kandidat.path) {
                    self.root = kandidat.appendingPathComponent(Self.folderName, isDirectory: true)
                    self.imDrive = true
                    return
                }
            }
        }
        self.root = lokal
        self.imDrive = false
    }

    public init(root: URL, ausweich: URL? = nil, imDrive: Bool = false) {
        self.root = root
        self.ausweich = ausweich ?? root
        self.imDrive = imDrive
    }

    public struct Ort: Sendable, Equatable {
        public var customer: String?
        public var projectNumber: String?
        public var projectTitle: String?
        public var work: String

        public init(customer: String? = nil, projectNumber: String? = nil,
                    projectTitle: String? = nil, work: String = "") {
            self.customer = customer; self.projectNumber = projectNumber
            self.projectTitle = projectTitle; self.work = work
        }
    }

    public static let ohneProjektOrdner = "_Ohne Projekt"
    public static let ohneKundeOrdner = "_Ohne Kunde"
    public static let ohneTitelOrdner = "_Ohne Titel"

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "yy-MM-dd"
        return f
    }()

    public static func projektPfad(_ ort: Ort) -> [String] {
        let customer = sauber(ort.customer ?? "")
        let nr = sauber(ort.projectNumber?.trimmingCharacters(in: .whitespaces) ?? "")
        let title = sauber(ort.projectTitle ?? "")
        let projekt = nr.isEmpty ? ohneProjektOrdner : (title.isEmpty ? nr : "\(nr) \(title)")
        return [customer.isEmpty ? ohneKundeOrdner : customer, projekt]
    }

    public static func werkPfad(_ ort: Ort, editor: ArbeitsstandEditor) -> [String] {
        let work = sauber(ort.work)
        return projektPfad(ort) + [editor.folderName, work.isEmpty ? ohneTitelOrdner : work]
    }

    public func projectFolder(_ ort: Ort) -> URL {
        Self.projektPfad(ort).reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }
    }

    public func load(fuer editor: ArbeitsstandEditor, in ort: Ort) -> URL {
        projectFolder(ort).appendingPathComponent(editor.folderName, isDirectory: true)
    }

    public func folder(fuer editor: ArbeitsstandEditor, in ort: Ort) -> URL {
        Self.werkPfad(ort, editor: editor).reduce(root) {
            $0.appendingPathComponent($1, isDirectory: true)
        }
    }

    public static func standName(kuerzel: String, wann: Date = Date()) -> String {
        "\(dateFormat.string(from: wann))_\(sauber(kuerzel.isEmpty ? "??" : kuerzel))"
    }

    static func sauber(_ roh: String) -> String {
        let erlaubt = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-äöüÄÖÜß "))
        var text = String(roh.unicodeScalars.map { erlaubt.contains($0) ? Character($0) : "-" })
        while text.contains("--") { text = text.replacingOccurrences(of: "--", with: "-") }
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "-. "))
    }

    static func saubererDateiname(_ roh: String) -> String {
        let url = URL(fileURLWithPath: roh)
        let endung = url.pathExtension
        let stamm = sauber(url.deletingPathExtension().lastPathComponent)
        let kern = stamm.isEmpty ? "datei" : stamm
        return endung.isEmpty ? kern : "\(kern).\(sauber(endung))"
    }

    @discardableResult
    public func save(editor: ArbeitsstandEditor, ort: Ort, kuerzel: String, data: Data,
                        beilagen: [(name: String, content: Data)] = [],
                        wann: Date = Date(), erreichbar: Bool = true) throws -> URL {
        let bevorzugt = (imDrive && erreichbar) ? root : ausweich
        do {
            return try schreibe(in: bevorzugt, editor: editor, ort: ort, kuerzel: kuerzel,
                                data: data, beilagen: beilagen, wann: wann)
        } catch {
            guard bevorzugt.path != ausweich.path else { throw error }
            return try schreibe(in: ausweich, editor: editor, ort: ort, kuerzel: kuerzel,
                                data: data, beilagen: beilagen, wann: wann)
        }
    }

    private func schreibe(in root: URL, editor: ArbeitsstandEditor, ort: Ort, kuerzel: String,
                          data: Data, beilagen: [(name: String, content: Data)],
                          wann: Date) throws -> URL {
        let target = Self.werkPfad(ort, editor: editor)
            .reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }
            .appendingPathComponent(Self.standName(kuerzel: kuerzel, wann: wann), isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try data.write(to: target.appendingPathComponent(editor.fileName), options: .atomic)
        for beilage in beilagen {
            let file = target.appendingPathComponent(Self.saubererDateiname(beilage.name))
            if Self.istSchonDa(beilage.content, at: file) { continue }
            try beilage.content.write(to: file, options: .atomic)
        }
        return target
    }

    static func istSchonDa(_ content: Data, at file: URL) -> Bool {
        guard let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
              values.fileSize == content.count else { return false }
        guard let vorhanden = try? Data(contentsOf: file, options: .mappedIfSafe) else { return false }
        return vorhanden == content
    }

    public struct Werk: Identifiable, Sendable, Equatable {
        public let id: String
        public let editor: ArbeitsstandEditor
        public let folder: URL
        public var customer: String?
        public var projekt: String?
        public var title: String
        public var staende: [Arbeitsstand]

        public var projectFolder: URL {
            folder.deletingLastPathComponent().deletingLastPathComponent()
        }

        public var newest: Arbeitsstand? { staende.first }
        public var anzahlFassungen: Int { staende.count }
    }

    private func subfolder(_ u: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: u, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func works(editor: ArbeitsstandEditor) -> [Werk] {
        var zusammen: [String: Werk] = [:]
        for root in wurzeln {
            for work in works(editor: editor, in: root) {
                let key = Self.werkPfad(.init(customer: work.customer, projectNumber: work.projekt,
                                                     work: work.title), editor: editor).joined(separator: "/")
                guard let schon = zusammen[key] else { zusammen[key] = work; continue }
                zusammen[key] = Self.lege(work, auf: schon)
            }
        }
        return zusammen.values
            .sorted { ($0.newest?.geaendertAm ?? .distantPast) > ($1.newest?.geaendertAm ?? .distantPast) }
    }

    private static func lege(_ neu: Werk, auf alt: Werk) -> Werk {
        var staende = alt.staende
        for state in neu.staende {
            if let i = staende.firstIndex(where: {
                $0.folder.lastPathComponent == state.folder.lastPathComponent
            }) {
                if state.geaendertAm > staende[i].geaendertAm { staende[i] = state }
            } else {
                staende.append(state)
            }
        }
        return Werk(id: alt.id, editor: alt.editor, folder: alt.folder,
                    customer: alt.customer ?? neu.customer, projekt: alt.projekt ?? neu.projekt,
                    title: alt.title, staende: staende.sorted { $0.geaendertAm > $1.geaendertAm })
    }

    var wurzeln: [URL] {
        root.path == ausweich.path ? [root] : [root, ausweich]
    }

    private func works(editor: ArbeitsstandEditor, in root: URL) -> [Werk] {
        let fm = FileManager.default
        var result: [Werk] = []
        for kundeOrdner in subfolder(root) where kundeOrdner.lastPathComponent != Self.uebertragenOrdner {
            for projekt in subfolder(kundeOrdner) {
                let load = projekt.appendingPathComponent(editor.folderName, isDirectory: true)
                guard fm.fileExists(atPath: load.path) else { continue }
                let ohneProjekt = projekt.lastPathComponent == Self.ohneProjektOrdner
                let ohneKunde = kundeOrdner.lastPathComponent == Self.ohneKundeOrdner
                let (number, _) = Self.zerlegeWerkOrdner(projekt.lastPathComponent,
                                                         ohneProjekt: ohneProjekt)
                for workFolder in subfolder(load) {
                    let werkTitel = workFolder.lastPathComponent
                    let staende: [Arbeitsstand] = subfolder(workFolder).compactMap { state in
                        guard fm.fileExists(atPath: state.appendingPathComponent(editor.fileName).path)
                        else { return nil }
                        let teile = state.lastPathComponent.split(separator: "_").map(String.init)
                        let wann = (try? state.resourceValues(forKeys: [.contentModificationDateKey]))?
                            .contentModificationDate ?? Date.distantPast
                        return Arbeitsstand(id: state.path, editor: editor, folder: state,
                                            projectNumber: number,
                                            title: werkTitel,
                                            kuerzel: teile.count >= 2 ? teile[1] : "",
                                            geaendertAm: wann)
                    }
                    .sorted { $0.geaendertAm > $1.geaendertAm }
                    guard staende.isEmpty == false else { continue }
                    result.append(Werk(id: workFolder.path, editor: editor, folder: workFolder,
                                         customer: ohneKunde ? nil : kundeOrdner.lastPathComponent,
                                         projekt: ohneProjekt ? nil : projekt.lastPathComponent,
                                         title: werkTitel,
                                         staende: staende))
                }
            }
        }
        return result
    }

    static func zerlegeWerkOrdner(_ name: String, ohneProjekt: Bool) -> (String?, String) {
        guard ohneProjekt == false else { return (nil, "") }
        guard let gap = name.firstIndex(of: " ") else { return (name, "") }
        return (String(name[name.startIndex..<gap]),
                String(name[name.index(after: gap)...]))
    }

    public func list(editor: ArbeitsstandEditor) -> [Arbeitsstand] {
        works(editor: editor).flatMap(\.staende).sorted { $0.geaendertAm > $1.geaendertAm }
    }

    public func alle() -> [Werk] {
        ArbeitsstandEditor.allCases.flatMap { works(editor: $0) }
            .sorted { ($0.newest?.geaendertAm ?? .distantPast) > ($1.newest?.geaendertAm ?? .distantPast) }
    }

    public struct OffenerStand: Identifiable, Sendable, Equatable {
        public let id: String
        public let editor: ArbeitsstandEditor
        public let source: URL
        public let target: URL
        public let pfad: String
        public let geaendertAm: Date
    }

    public func offeneStaende() -> [OffenerStand] {
        guard imDrive else { return [] }
        let fm = FileManager.default
        var result: [OffenerStand] = []
        for customer in subfolder(ausweich) where customer.lastPathComponent != Self.uebertragenOrdner {
            for projekt in subfolder(customer) {
                for load in subfolder(projekt) {
                    guard let editor = ArbeitsstandEditor.allCases
                        .first(where: { $0.folderName == load.lastPathComponent }) else { continue }
                    for work in subfolder(load) {
                        for state in subfolder(work) {
                            guard fm.fileExists(atPath: state.appendingPathComponent(editor.fileName).path)
                            else { continue }
                            let teile = [customer, projekt, load, work, state].map(\.lastPathComponent)
                            let target = teile.reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }
                            let wann = (try? state.resourceValues(forKeys: [.contentModificationDateKey]))?
                                .contentModificationDate ?? Date.distantPast
                            result.append(OffenerStand(id: state.path, editor: editor,
                                                         source: state, target: target,
                                                         pfad: teile.joined(separator: "/"),
                                                         geaendertAm: wann))
                        }
                    }
                }
            }
        }
        return result.sorted { $0.geaendertAm > $1.geaendertAm }
    }

    public struct UebertragBericht: Sendable, Equatable {
        public var uebertragen: [String] = []
        public var kollisionen: [String] = []
        public var error: [String] = []
    }

    @discardableResult
    public func uebertrageOffene(_ staende: [OffenerStand]? = nil) -> UebertragBericht {
        let fm = FileManager.default
        var bericht = UebertragBericht()
        for state in staende ?? offeneStaende() {
            if fm.fileExists(atPath: state.target.path) {
                bericht.kollisionen.append(state.pfad)
                continue
            }
            do {
                try fm.createDirectory(at: state.target.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try fm.copyItem(at: state.source, to: state.target)
                let beiseite = ausweich.appendingPathComponent(Self.uebertragenOrdner, isDirectory: true)
                    .appendingPathComponent(state.pfad, isDirectory: true)
                try fm.createDirectory(at: beiseite.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try fm.moveItem(at: state.source, to: beiseite)
                bericht.uebertragen.append(state.pfad)
            } catch {
                bericht.error.append("\(state.pfad) — \(error.localizedDescription)")
            }
        }
        return bericht
    }
}
