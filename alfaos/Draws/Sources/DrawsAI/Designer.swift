import DrawingKit
import Foundation

public struct Attachment: Sendable, Equatable {
    public enum Role: String, Sendable, CaseIterable, Codable {
        case moodboard, template, sketch, drawing, reference
    }

    public var name: String
    public var data: Data
    public var mediaType: String
    public var role: Role
    public var note: String

    public init(name: String, data: Data, mediaType: String, role: Role = .reference, note: String = "") {
        self.name = name; self.data = data; self.mediaType = mediaType; self.role = role; self.note = note
    }

    public static let images = ["image/png", "image/jpeg", "image/gif", "image/webp"]
    public static let document = "application/pdf"
    public static let text = "text/plain"

    public var supported: Bool { Self.images.contains(mediaType) || mediaType == Self.document || mediaType == Self.text }
}

public struct Brief: Sendable {
    public var text: String
    public var attachments: [Attachment]
    public var current: [Part]
    public var materials: [String]
    public var catalog: [String]

    public init(text: String, attachments: [Attachment] = [], current: [Part] = [], materials: [String],
                catalog: [String] = []) {
        self.text = text; self.attachments = attachments; self.current = current; self.materials = materials
        self.catalog = catalog
    }
}

public struct Proposal: Sendable, Codable, Equatable {
    public var parts: [Part]
    public var project: [String: String]
    public var products: [String]
    public var assumptions: [String]
    public var questions: [String]
    public var variants: [Variant]
    public var materials: [Material]

    public init(parts: [Part], project: [String: String], products: [String], assumptions: [String], questions: [String],
                variants: [Variant] = [], materials: [Material] = []) {
        self.parts = parts; self.project = project; self.products = products
        self.assumptions = assumptions; self.questions = questions; self.variants = variants; self.materials = materials
    }
}

public enum DesignError: Error, Equatable, Sendable {
    case noKey
    case emptyBrief
    case unsupported(String)
    case refused(String)
    case truncated
    case http(Int, String)
    case malformed(String)
    case invalid(DrawingError)
    case unknownMaterial(String)
    case invalidMaterial(String)
    case duplicateMaterial(String)
    case tooLarge
    case stale
    case noModel
    case noStructuredOutput(String)
}

public protocol Designer: Sendable {
    func design(_ brief: Brief) async throws -> Proposal
}
