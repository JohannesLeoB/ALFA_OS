import Foundation
import UniformTypeIdentifiers

/// Reads what the system gives for a paste or a drop: a list of item providers.
/// For each provider, the first match counts: a file, then an image, then an address, then text.
/// A file comes before the image of its icon, which the system adds to a copied file.
public enum ProviderReader {
    @MainActor
    public static func sources(from providers: [NSItemProvider]) async -> [ImportSource] {
        var out: [ImportSource] = []
        for provider in providers {
            if let source = await source(from: provider) { out.append(source) }
        }
        return out
    }

    @MainActor
    private static func source(from provider: NSItemProvider) async -> ImportSource? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await fileURL(from: provider) {
            return .file(url)
        }
        if let type = provider.registeredTypeIdentifiers.compactMap({ UTType($0) }).first(where: { $0.conforms(to: .image) }),
           let data = await data(from: provider, type: type) {
            return .image(data, fileExtension: type.preferredFilenameExtension ?? "png", name: provider.suggestedName)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await webURL(from: provider) {
            return .text(url.absoluteString)
        }
        if let type = provider.registeredTypeIdentifiers.compactMap({ UTType($0) }).first(where: { $0.conforms(to: .plainText) }),
           let data = await data(from: provider, type: type),
           let text = String(data: data, encoding: type.identifier == UTType.utf16PlainText.identifier ? .utf16 : .utf8) {
            return .text(text)
        }
        return nil
    }

    @MainActor
    private static func fileURL(from provider: NSItemProvider) async -> URL? {
        await url(from: provider, type: .fileURL)
    }

    @MainActor
    private static func webURL(from provider: NSItemProvider) async -> URL? {
        await url(from: provider, type: .url)
    }

    /// The system gives an address as a URL or as its bytes.
    @MainActor
    private static func url(from provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                if let url = item as? URL { continuation.resume(returning: url) }
                else if let data = item as? Data { continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil)) }
                else { continuation.resume(returning: nil) }
            }
        }
    }

    @MainActor
    private static func data(from provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
