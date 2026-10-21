import CoreText
import Foundation

public struct SheetFonts: Sendable, Equatable {
    public var sans: String

    public init(sans: String) {
        self.sans = sans
    }

    public static func upload(_ folder: URL) -> SheetFonts? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var names: [String] = []
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where ["otf", "ttf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            names += descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        }
        let plain = names.filter { !$0.lowercased().contains("italic") }
        let sans = plain.filter { !$0.lowercased().contains("mono") }
        func pick(_ list: [String]) -> String? {
            list.first { $0.lowercased().contains("medium") } ?? list.first { $0.lowercased().contains("regular") } ?? list.first
        }
        return (pick(sans) ?? pick(plain)).map(SheetFonts.init)
    }
}
