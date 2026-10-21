import CoreText
import Foundation

public enum Fonts {
    public static func upload(_ folder: URL) -> [FontFace] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var names: [String] = []
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where ["otf", "ttf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            names += descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        }
        let plain = names.filter { !$0.lowercased().contains("italic") }
        let proportional = plain.filter { !$0.lowercased().contains("mono") }
        let fixed = plain.filter { $0.lowercased().contains("mono") }
        func pick(_ list: [String]) -> String? {
            list.first { $0.lowercased().contains("medium") } ?? list.first { $0.lowercased().contains("regular") } ?? list.first
        }
        var faces: [FontFace] = []
        if let sans = pick(proportional) ?? pick(plain) { faces.append(FontFace(role: .sans, family: sans)) }
        if let mono = pick(fixed) { faces.append(FontFace(role: .mono, family: mono)) }
        return faces
    }
}
