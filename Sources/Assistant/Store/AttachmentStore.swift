import Core
import CryptoKit
import Design
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct AttachmentStore: AttachmentPort {
    static let imageLongEdge = 1568
    static let imageByteLimit = 4_000_000
    static let documentByteLimit = Tokens.Count.chatDocumentByteLimit
    static let wireImageTypes: Set<String> = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    static let textCharacterLimit = Tokens.Count.chatTextCharacterLimit

    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    static func mimeType(of url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }

    var directory: URL { root.appendingPathComponent("chat-attachments", isDirectory: true) }

    public func save(_ url: URL) async throws -> AttachmentRef {
        let name = url.lastPathComponent
        let mime = Self.mimeType(of: url)
        guard let kind = AttachmentKind(mimeType: mime) else { throw AttachmentFailure.unsupported(name) }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        if kind == .pdf, let size, size > Self.documentByteLimit { throw AttachmentFailure.tooLarge(name) }
        guard let data = try? Data(contentsOf: url) else { throw AttachmentFailure.unreadable(name) }
        return try save(Attachment(filename: name, mimeType: mime, data: data))
    }

    public func sweep(keeping paths: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where paths.contains(file.lastPathComponent) == false {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                Log.failure("AttachmentUnswept", detail: String(describing: error))
            }
        }
    }

    func save(_ file: Attachment) throws -> AttachmentRef {
        guard let kind = AttachmentKind(mimeType: file.mimeType) else { throw AttachmentFailure.unsupported(file.filename) }
        var mime = file.mimeType
        var data = file.data
        switch kind {
        case .image:
            if Self.wireImageTypes.contains(mime) == false || data.count > Self.imageByteLimit {
                guard let jpeg = Self.jpegData(from: data) else { throw AttachmentFailure.unreadable(file.filename) }
                data = jpeg
                mime = "image/jpeg"
            }
            if data.count > Self.imageByteLimit { throw AttachmentFailure.tooLarge(file.filename) }
        case .pdf:
            if data.count > Self.documentByteLimit { throw AttachmentFailure.tooLarge(file.filename) }
        case .text:
            guard let text = String(data: data, encoding: .utf8) else { throw AttachmentFailure.unreadable(file.filename) }
            if text.count > Self.textCharacterLimit { throw AttachmentFailure.tooLarge(file.filename) }
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let ext = mime == file.mimeType ? (file.filename as NSString).pathExtension : "jpg"
        let name = ext.isEmpty ? digest : digest + "." + ext
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) == false { try data.write(to: url, options: .atomic) }
        return AttachmentRef(fileName: file.filename, mimeType: mime, byteCount: data.count, relativePath: name, sha256: digest)
    }

    func data(for ref: AttachmentRef) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(ref.relativePath))
    }

    static func jpegData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: imageLongEdge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

struct ArtifactStore: ArtifactPort {
    private let root: URL

    init(root: URL) {
        self.root = root
    }

    var folder: URL { root.appendingPathComponent("erzeugnisse", isDirectory: true) }

    static func stamp(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func safeName(_ raw: String, at date: Date) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_. \u{E4}\u{F6}\u{FC}\u{C4}\u{D6}\u{DC}\u{DF}"))
        var cleaned = String(raw.unicodeScalars.filter { allowed.contains($0) })
        while cleaned.contains("..") { cleaned = cleaned.replacingOccurrences(of: "..", with: ".") }
        let core = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return "\(stamp(date, "HHmmss"))_\(core.isEmpty ? "file" : core)"
    }

    @discardableResult
    func write(_ data: Data, name: String, at date: Date = Date()) throws -> URL {
        let day = folder.appendingPathComponent(Self.stamp(date, "yyyy-MM-dd"), isDirectory: true)
        try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        let target = day.appendingPathComponent(Self.safeName(name, at: date))
        try data.write(to: target, options: .atomic)
        return target
    }
}
