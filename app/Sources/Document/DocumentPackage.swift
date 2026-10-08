import Foundation
import SetzkastenCore
import Tokens

/// Der Weg zwischen `SetzkastenDocument` und dem Ordnerpaket `.setzkasten`.
///
/// Aufbau eines Pakets:
/// ```
/// Name.setzkasten/
///   manifest.json                          Formatversion, App-Version, Titel, Reihenfolge der Räume und Tokensätze
///   spaces/<raum>/space.json               Raum: Name, Ebenen-Reihenfolge
///   spaces/<raum>/layers/<ebene>.json      Ebene samt ihren Stücken (eine Ebene je Datei, das senkt Konflikte)
///   assets/<sha256>.<ext>                  Bilder, einmal je Inhalt
///   tokens/<satz>.tokens.json              Tokensatz als DTCG
///   history/  inbox/                       gehören späteren Briefen; Inhalt wird unverändert mitgeführt
/// ```
/// `<raum>`, `<ebene>`, `<satz>` sind die IDs bzw. Namen, falls nötig als %XX geschrieben (siehe `PackageNaming`).
public enum DocumentPackage {
    public static let typeIdentifier = "com.johannesleoberger.setzkasten"
    public static let fileExtension = "setzkasten"

    // MARK: Schreiben

    /// Das Paket als Ordner-FileWrapper, bereit für `ReferenceFileDocument` und für `write(_:to:)`.
    /// Alles wird im Speicher gebaut und geprüft, bevor etwas auf die Platte kommt: ein Fehler lässt ein vorhandenes Paket unberührt.
    public static func fileWrapper(for document: SetzkastenDocument, appVersion: String) throws -> FileWrapper {
        try makeWrapper(from: files(for: document, appVersion: appVersion))
    }

    /// Schreibt atomar: erst in eine Temp-Datei neben dem Ziel, dann wird das alte Paket ersetzt.
    /// Das Koordinieren mit anderen Prozessen (NSFileCoordinator) gehört in die Fenster-Anbindung.
    public static func write(_ document: SetzkastenDocument, to url: URL, appVersion: String) throws {
        let wrapper = try fileWrapper(for: document, appVersion: appVersion)
        do {
            try wrapper.write(to: url, options: [.atomic], originalContentsURL: nil)
        } catch {
            throw PackageError.writeFailed(reason: error.localizedDescription)
        }
    }

    static func files(for doc: SetzkastenDocument, appVersion: String) throws -> PackageFiles {
        var files = PackageFiles()
        func put(_ path: String, _ data: Data) throws {
            guard files.updateValue(data, forKey: path) == nil else { throw PackageError.invalidPath(path) }
        }
        let version = Migration.currentVersion
        let spaces = doc.board.spaces

        let spaceDirs = try PackageNaming.requireDistinct(spaces.map(\.id), kind: "Raum")
        for space in spaces {
            let dir = "spaces/\(spaceDirs[space.id]!)"
            let layerNames = try PackageNaming.requireDistinct(space.layers.map(\.id), kind: "Ebene")
            let layerIndex = Dictionary(uniqueKeysWithValues: space.layers.enumerated().map { ($1.id, $0) })

            var grouped: [String: [ItemEnvelope]] = [:]
            var sequence: [Int] = []
            sequence.reserveCapacity(space.items.count)
            for item in space.items {
                guard let index = layerIndex[item.layerID] else {
                    throw PackageError.itemWithoutLayer(item: item.id.raw, layer: item.layerID, space: space.id)
                }
                grouped[item.layerID, default: []].append(ItemEnvelope(item, extras: doc.preserved.items[item.id] ?? [:]))
                sequence.append(index)
            }
            let ordered = sequence == sequence.sorted()

            let spaceFile = SpaceFile(schema: version, id: space.id, name: space.name, layers: space.layers.map(\.id),
                                      layerSequence: ordered ? nil : sequence, extras: doc.preserved.spaces[space.id] ?? [:])
            try put("\(dir)/space.json", try encode(spaceFile, path: "\(dir)/space.json"))
            for layer in space.layers {
                let path = "\(dir)/layers/\(layerNames[layer.id]!).json"
                let file = LayerFile(schema: version, layer: layer, items: grouped[layer.id] ?? [],
                                     extras: doc.preserved.layers[LayerKey(space: space.id, layer: layer.id)] ?? [:])
                try put(path, try encode(file, path: path))
            }
        }

        for (id, entry) in doc.assets.entries {
            try put("assets/\(id).\(entry.fileExtension)", entry.data)
        }

        let tokenNames = try PackageNaming.requireDistinct(doc.tokenSets.map(\.name), kind: "Tokensatz")
        for set in doc.tokenSets {
            let path = "tokens/\(tokenNames[set.name]!).tokens.json"
            do {
                try put(path, try TokenFile.data(for: set, extras: doc.preserved.tokenFiles[set.name] ?? [:]))
            } catch let e as EncodingError {
                throw PackageError.writeFailed(reason: "\(path): \(describe(e))")
            }
        }

        let manifest = ManifestFile(formatVersion: version, lastWrittenByAppVersion: appVersion, title: doc.board.title,
                                    spaces: spaces.map(\.id), tokenSets: doc.tokenSets.map(\.name), extras: doc.preserved.manifest)
        try put("manifest.json", try encode(manifest, path: "manifest.json"))

        for (path, data) in doc.carriedFiles {
            guard PackageNaming.isSafe(path: path) else { throw PackageError.invalidPath(path) }
            try put(path, data)
        }
        return files
    }

    private static func encode<T: Encodable>(_ value: T, path: String) throws -> Data {
        do { return try PackageJSON.data(value) } catch let e as EncodingError {
            throw PackageError.writeFailed(reason: "\(path): \(describe(e))")
        }
    }

    /// Ordner mit allen Dateien; die Ordner des Aufbaus gibt es auch, wenn sie leer sind.
    static func makeWrapper(from files: PackageFiles) throws -> FileWrapper {
        final class Node {
            var dirs: [String: Node] = [:]
            var files: [String: Data] = [:]
        }
        let root = Node()
        for name in ["spaces", "assets", "tokens", "history", "inbox"] { root.dirs[name] = Node() }
        for (path, data) in files {
            let parts = path.split(separator: "/").map(String.init)
            var node = root
            for dir in parts.dropLast() {
                guard node.files[dir] == nil else { throw PackageError.invalidPath(path) }   // Datei und Ordner mit demselben Namen
                if node.dirs[dir] == nil { node.dirs[dir] = Node() }
                node = node.dirs[dir]!
            }
            guard let leaf = parts.last, node.dirs[leaf] == nil, node.files.updateValue(data, forKey: leaf) == nil else {
                throw PackageError.invalidPath(path)
            }
        }
        func build(_ node: Node, name: String?) -> FileWrapper {
            var children: [String: FileWrapper] = [:]
            for (n, data) in node.files {
                let w = FileWrapper(regularFileWithContents: data)
                w.preferredFilename = n
                children[n] = w
            }
            for (n, child) in node.dirs { children[n] = build(child, name: n) }
            let dir = FileWrapper(directoryWithFileWrappers: children)
            if let name { dir.preferredFilename = name }   // nil wirft eine NSException
            return dir
        }
        return build(root, name: nil)
    }

    // MARK: Lesen

    public static func read(from url: URL, options: ReadOptions = ReadOptions(), migration: Migration = .standard) throws -> DocumentReadResult {
        let wrapper: FileWrapper
        do { wrapper = try FileWrapper(url: url, options: []) } catch {
            throw PackageError.unreadable(reason: "\(url.lastPathComponent): \(error.localizedDescription)")
        }
        return try read(from: wrapper, options: options, migration: migration)
    }

    public static func read(from wrapper: FileWrapper, options: ReadOptions = ReadOptions(), migration: Migration = .standard) throws -> DocumentReadResult {
        guard wrapper.isDirectory else { throw PackageError.notAPackage }
        var report = ReadReport()
        var files = PackageFiles()
        try flatten(wrapper, prefix: "", into: &files, warnings: &report.warnings)

        // 1. Version prüfen, nötigenfalls migrieren
        guard let manifestData = files["manifest.json"] else { throw PackageError.missingFile(path: "manifest.json") }
        struct VersionProbe: Decodable { var formatVersion: Int }
        let onDisk = try decode(VersionProbe.self, from: manifestData, path: "manifest.json").formatVersion
        report.formatVersionOnDisk = onDisk
        guard onDisk >= 1 else { throw PackageError.corruptFile(path: "manifest.json", reason: "Formatversion \(onDisk) ist ungültig") }
        guard onDisk <= migration.currentVersion else { throw PackageError.unknownFormatVersion(onDisk) }
        if onDisk < migration.currentVersion {
            files = try migration.migrate(files, from: onDisk, to: migration.currentVersion)
            report.migratedFrom = onDisk
        }

        let manifest = try decode(ManifestFile.self, from: files["manifest.json"]!, path: "manifest.json")
        report.writtenByAppVersion = manifest.lastWrittenByAppVersion
        var claimed: Set<String> = ["manifest.json"]
        var preserved = PreservedFields()
        preserved.manifest = manifest.extras

        // 2. Räume und Ebenen
        let paths = files.keys.sorted()
        var layerPathsByDir: [String: [String]] = [:]
        for path in paths {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            if parts.count == 4, parts[0] == "spaces", parts[2] == "layers", path.hasSuffix(".json") { layerPathsByDir[String(parts[1]), default: []].append(path) }
        }
        var spaceFiles: [(dir: String, file: SpaceFile)] = []
        var seenSpaces = Set<String>()
        for path in paths {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == "spaces", parts[2] == "space.json" else { continue }
            let file = try decode(SpaceFile.self, from: files[path]!, path: path)
            try requireKnown(schema: file.schema, migration: migration)
            guard seenSpaces.insert(file.id).inserted else {
                report.warnings.append("Raum „\(file.id)“ steht in \(path) ein zweites Mal; die Datei bleibt unangetastet liegen und wird nicht geöffnet.")
                continue
            }
            claimed.insert(path)
            spaceFiles.append((String(parts[1]), file))
        }
        let byID = Dictionary(uniqueKeysWithValues: spaceFiles.map { ($0.file.id, $0) })
        var orderedSpaces: [(dir: String, file: SpaceFile)] = []
        for id in manifest.spaces {
            if let s = byID[id] { orderedSpaces.append(s) }
            else { report.warnings.append("Das Manifest nennt den Raum „\(id)“, aber seine space.json fehlt.") }
        }
        let listed = Set(orderedSpaces.map(\.file.id))
        orderedSpaces += spaceFiles.filter { !listed.contains($0.file.id) }.sorted { $0.dir < $1.dir }

        var spaces: [Space] = []
        var seenItems = Set<ItemID>()
        var duplicateItems = Set<ItemID>()
        for (dir, spaceFile) in orderedSpaces {
            preserved.spaces[spaceFile.id] = spaceFile.extras.isEmpty ? nil : spaceFile.extras

            var layerFiles: [String: LayerFile] = [:]
            var layerPaths: [(path: String, id: String)] = []
            for path in layerPathsByDir[dir] ?? [] {
                let file = try decode(LayerFile.self, from: files[path]!, path: path)
                try requireKnown(schema: file.schema, migration: migration)
                guard layerFiles[file.id] == nil else {
                    report.warnings.append("Ebene „\(file.id)“ im Raum „\(spaceFile.id)“ steht in \(path) ein zweites Mal; die Datei bleibt unangetastet liegen.")
                    continue
                }
                claimed.insert(path)
                layerFiles[file.id] = file
                layerPaths.append((path, file.id))
            }
            var layerOrder: [String] = []
            for id in spaceFile.layers {
                if layerFiles[id] != nil, !layerOrder.contains(id) { layerOrder.append(id) }
                else if layerFiles[id] == nil { report.warnings.append("Raum „\(spaceFile.id)“ nennt die Ebene „\(id)“, aber ihre Datei fehlt.") }
            }
            let listedLayers = Set(layerOrder)
            layerOrder += layerPaths.filter { !listedLayers.contains($0.id) }.map(\.id)

            var layers: [Layer] = []
            var itemsByLayer: [String: [Item]] = [:]
            for id in layerOrder {
                let file = layerFiles[id]!
                layers.append(file.layer)
                if !file.extras.isEmpty { preserved.layers[LayerKey(space: spaceFile.id, layer: id)] = file.extras }
                itemsByLayer[id] = file.items.map { env in
                    if !env.extras.isEmpty { preserved.items[env.item.id] = env.extras }
                    if !seenItems.insert(env.item.id).inserted { duplicateItems.insert(env.item.id) }
                    return env.item
                }
            }
            let items = interleave(itemsByLayer, order: layerOrder, written: spaceFile.layers, sequence: spaceFile.layerSequence) {
                report.warnings.append("Raum „\(spaceFile.id)“: \($0)")
            }
            spaces.append(Space(id: spaceFile.id, name: spaceFile.name, layers: layers, items: items))
        }
        if !duplicateItems.isEmpty {
            report.warnings.append("Stück-IDs kommen mehrfach vor: \(duplicateItems.map(\.raw).sorted().joined(separator: ", "))")
        }

        // 3. Bilder
        var assets = AssetStore()
        for path in paths {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0] == "assets", let dot = parts[1].lastIndex(of: ".") else { continue }
            let id = String(parts[1][..<dot]), ext = String(parts[1][parts[1].index(after: dot)...])
            guard AssetStore.isValidID(id), AssetStore.isValidExtension(ext), assets[id] == nil else { continue }
            claimed.insert(path)
            assets.insertLoaded(id: id, fileExtension: ext, data: files[path]!)
        }
        if options.verifyAssetHashes {
            report.corruptAssets = assets.ids.filter { AssetStore.hash(of: assets[$0]!.data) != $0 }
        }

        // 4. Tokensätze
        let suffix = ".tokens.json"
        var tokenSets: [String: TokenSet] = [:]
        for path in paths {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0] == "tokens", parts[1].hasSuffix(suffix) else { continue }
            let name = PackageNaming.decode(String(parts[1].dropLast(suffix.count)))
            guard tokenSets[name] == nil else { continue }
            let parsed = try TokenFile.parse(files[path]!, name: name, path: path)
            tokenSets[name] = parsed.set
            if !parsed.extras.isEmpty { preserved.tokenFiles[name] = parsed.extras }
            claimed.insert(path)
        }
        var orderedSets: [TokenSet] = []
        for name in manifest.tokenSets {
            if let s = tokenSets.removeValue(forKey: name) { orderedSets.append(s) }
            else if !orderedSets.contains(where: { $0.name == name }) { report.warnings.append("Das Manifest nennt den Tokensatz „\(name)“, aber seine Datei fehlt.") }
        }
        orderedSets += tokenSets.values.sorted { $0.name < $1.name }

        // 5. Alles andere mitführen
        var doc = SetzkastenDocument(board: Board(title: manifest.title, spaces: spaces), assets: assets, tokenSets: orderedSets)
        doc.board.format = migration.currentVersion
        doc.preserved = preserved
        for (path, data) in files where !claimed.contains(path) { doc.carriedFiles[path] = data }

        report.missingAssets = doc.missingAssets()
        let used = Set(spaces.flatMap(\.items).compactMap { item -> String? in
            if case .image(let id, _) = item.content { id } else { nil }
        })
        report.unreferencedAssets = assets.ids.filter { !used.contains($0) }
        return DocumentReadResult(document: doc, report: report)
    }

    /// Stellt die Reihenfolge von `Space.items` wieder her. Ohne (oder bei stimmigen Angaben fehlerhaftem) `sequence`: nach Ebenen geordnet.
    private static func interleave(_ itemsByLayer: [String: [Item]], order: [String], written: [String], sequence: [Int]?, warn: (String) -> Void) -> [Item] {
        let canonical = order.flatMap { itemsByLayer[$0] ?? [] }
        guard let sequence else { return canonical }
        var counts: [String: Int] = [:]
        var valid = sequence.count == canonical.count
        for index in sequence where valid {
            guard written.indices.contains(index) else { valid = false; break }
            counts[written[index], default: 0] += 1
        }
        valid = valid && order.allSatisfy { counts[$0, default: 0] == itemsByLayer[$0]?.count ?? 0 }
        guard valid else {
            warn("Die Stückreihenfolge (layerSequence) passt nicht zu den Ebenendateien; die Stücke liegen nach Ebenen geordnet.")
            return canonical
        }
        var cursor: [String: Int] = [:]
        var out: [Item] = []
        out.reserveCapacity(canonical.count)
        for index in sequence {
            let id = written[index]
            let n = cursor[id, default: 0]
            out.append(itemsByLayer[id]![n])
            cursor[id] = n + 1
        }
        return out
    }

    static func flatten(_ wrapper: FileWrapper, prefix: String, into files: inout PackageFiles, warnings: inout [String]) throws {
        for (name, child) in (wrapper.fileWrappers ?? [:]).sorted(by: { $0.key < $1.key }) {
            let path = prefix.isEmpty ? name : prefix + "/" + name
            if child.isDirectory {
                try flatten(child, prefix: path, into: &files, warnings: &warnings)
            } else if child.isRegularFile {
                if name == ".DS_Store" { continue }   // Finder-Müll, kein Inhalt
                guard let data = child.regularFileContents else { throw PackageError.corruptFile(path: path, reason: "Datei nicht lesbar") }
                files[path] = data
            } else {
                warnings.append("Verknüpfung \(path) wurde übersprungen.")
            }
        }
    }

    private static func requireKnown(schema: Int, migration: Migration) throws {
        if schema > migration.currentVersion { throw PackageError.unknownFormatVersion(schema) }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        do { return try PackageJSON.decoder().decode(type, from: data) } catch let e as DecodingError {
            throw PackageError.corruptFile(path: path, reason: describe(e))
        }
    }

    private static func describe(_ e: DecodingError) -> String {
        func at(_ c: DecodingError.Context) -> String {
            let p = c.codingPath.map { $0.stringValue }.joined(separator: ".")
            return p.isEmpty ? "" : " bei \(p)"
        }
        switch e {
        case .keyNotFound(let k, let c): return "Feld „\(k.stringValue)“ fehlt\(at(c))"
        case .typeMismatch(_, let c), .valueNotFound(_, let c), .dataCorrupted(let c): return "\(c.debugDescription)\(at(c))"
        @unknown default: return "unlesbar"
        }
    }
    private static func describe(_ e: EncodingError) -> String {
        switch e {
        case .invalidValue(_, let c): c.debugDescription
        @unknown default: "nicht schreibbar"
        }
    }
}
