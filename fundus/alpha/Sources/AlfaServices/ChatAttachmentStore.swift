import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import AlfaKit

public enum ChatAttachmentStore {
    public static let imageLongEdge = 1568
    public static let imageByteLimit = 4_000_000
    public static let documentByteLimit = 20_000_000
    public static let textCharacterLimit = 120_000

    public static let wireImageTypes: Set<String> = ["image/jpeg", "image/png", "image/gif", "image/webp"]

    public enum Kind: Equatable { case image, pdf, text }

    public enum StoreError: Error, Equatable {
        case unsupported(String)
        case tooLarge(String)
        case unreadable(String)
    }

    public static func kind(forMimeType mime: String) -> Kind? {
        if mime.hasPrefix("image/") { return .image }
        if mime == "application/pdf" { return .pdf }
        if mime.hasPrefix("text/") || mime == "application/json" { return .text }
        return nil
    }

    public static func directory(root: URL = DatenRoot.root()) -> URL {
        root.appendingPathComponent("chat-anhaenge", isDirectory: true)
    }

    public static func save(_ file: DroppedFile, root: URL = DatenRoot.root()) throws -> ChatAttachmentRef {
        guard let kind = kind(forMimeType: file.mimeType) else { throw StoreError.unsupported(file.fileName) }
        var mime = file.mimeType
        var data = file.data
        switch kind {
        case .image:
            if wireImageTypes.contains(mime) == false || data.count > imageByteLimit {
                guard let jpeg = jpegData(from: data) else { throw StoreError.unreadable(file.fileName) }
                data = jpeg
                mime = "image/jpeg"
            }
            if data.count > imageByteLimit { throw StoreError.tooLarge(file.fileName) }
        case .pdf:
            if data.count > documentByteLimit { throw StoreError.tooLarge(file.fileName) }
        case .text:
            guard String(data: data, encoding: .utf8) != nil else { throw StoreError.unreadable(file.fileName) }
        }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let ext = mime == file.mimeType ? (file.fileName as NSString).pathExtension : "jpg"
        let name = ext.isEmpty ? sha : sha + "." + ext
        let dir = directory(root: root)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) == false {
            try data.write(to: url, options: .atomic)
        }
        return ChatAttachmentRef(fileName: file.fileName, mimeType: mime, byteCount: data.count, relativePath: name, sha256: sha)
    }

    public static func url(for ref: ChatAttachmentRef, root: URL = DatenRoot.root()) -> URL {
        directory(root: root).appendingPathComponent(ref.relativePath)
    }

    public static func data(for ref: ChatAttachmentRef, root: URL = DatenRoot.root()) -> Data? {
        try? Data(contentsOf: url(for: ref, root: root))
    }

    static func jpegData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: imageLongEdge
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
