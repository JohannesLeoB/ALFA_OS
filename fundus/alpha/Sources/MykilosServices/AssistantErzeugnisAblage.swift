import Foundation
import MykilosKit

public enum AssistantErzeugnisAblage {
    public static func folder(root: URL = DatenRoot.root()) -> URL {
        root.appendingPathComponent("erzeugnisse", isDirectory: true)
    }

    private static let tagesFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let zeitFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HHmmss"
        return f
    }()

    public static func sichererName(_ roh: String, wann: Date = Date()) -> String {
        let erlaubt = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_. äöüÄÖÜß"))
        var geputzt = String(roh.unicodeScalars.filter { erlaubt.contains($0) })
        while geputzt.contains("..") { geputzt = geputzt.replacingOccurrences(of: "..", with: ".") }
        let kern = geputzt.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return "\(zeitFormat.string(from: wann))_\(kern.isEmpty ? "file" : kern)"
    }

    @discardableResult
    public static func schreibe(_ data: Data, name: String, wann: Date = Date(),
                                root: URL = DatenRoot.root()) throws -> URL {
        let tag = folder(root: root).appendingPathComponent(tagesFormat.string(from: wann),
                                                            isDirectory: true)
        try FileManager.default.createDirectory(at: tag, withIntermediateDirectories: true)
        let target = tag.appendingPathComponent(sichererName(name, wann: wann))
        try data.write(to: target, options: .atomic)
        return target
    }
}
