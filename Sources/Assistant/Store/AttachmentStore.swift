import CryptoKit
import Core
import Design
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct AttachmentStore: Sendable {
    public enum Kind: Equatable, Sendable { case image, pdf, text }

    public enum Failure: Error, Equatable {
        case unsupported(String)
        case tooLarge(String)
        case unreadable(String)
    }

    static let imageLongEdge = 1568
    static let imageByteLimit = 4_000_000
    static let documentByteLimit = Tokens.Count.chatDocumentByteLimit
    static let wireImageTypes: Set<String> = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    static let textCharacterLimit = Tokens.Count.chatTextCharacterLimit

    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func kind(forMimeType mime: String) -> Kind? {
        if mime.hasPrefix("image/") { return .image }
        if mime == "application/pdf" { return .pdf }
        if mime.hasPrefix("text/") || mime == "application/json" { return .text }
        return nil
    }

    var directory: URL { root.appendingPathComponent("chat-attachments", isDirectory: true) }

    public func save(_ file: Attachment) throws -> AttachmentRef {
        guard let kind = Self.kind(forMimeType: file.mimeType) else { throw Failure.unsupported(file.filename) }
        var mime = file.mimeType
        var data = file.data
        switch kind {
        case .image:
            if Self.wireImageTypes.contains(mime) == false || data.count > Self.imageByteLimit {
                guard let jpeg = Self.jpegData(from: data) else { throw Failure.unreadable(file.filename) }
                data = jpeg
                mime = "image/jpeg"
            }
            if data.count > Self.imageByteLimit { throw Failure.tooLarge(file.filename) }
        case .pdf:
            if data.count > Self.documentByteLimit { throw Failure.tooLarge(file.filename) }
        case .text:
            guard let text = String(data: data, encoding: .utf8) else { throw Failure.unreadable(file.filename) }
            if text.count > Self.textCharacterLimit { throw Failure.tooLarge(file.filename) }
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let ext = mime == file.mimeType ? (file.filename as NSString).pathExtension : "jpg"
        let name = ext.isEmpty ? digest : digest + "." + ext
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) == false { try data.write(to: url, options: .atomic) }
        return AttachmentRef(fileName: file.filename, mimeType: mime, byteCount: data.count, relativePath: name, sha256: digest)
    }

    public func data(for ref: AttachmentRef) -> Data? {
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
