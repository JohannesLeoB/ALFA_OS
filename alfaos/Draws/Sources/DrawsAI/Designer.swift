import DrawingKit
import Foundation

public struct Attachment: Sendable, Equatable {
    public var name: String
    public var data: Data
    public var mediaType: String

    public init(name: String, data: Data, mediaType: String) {
        self.name = name; self.data = data; self.mediaType = mediaType
    }

    public static let images = ["image/png", "image/jpeg", "image/gif", "image/webp"]
    public static let document = "application/pdf"

    public var supported: Bool { Self.images.contains(mediaType) || mediaType == Self.document }
}

public struct Brief: Sendable {
    public var text: String
    public var attachments: [Attachment]
    public var current: [Part]
    public var materials: [String]

    public init(text: String, attachments: [Attachment] = [], current: [Part] = [], materials: [String]) {
        self.text = text; self.attachments = attachments; self.current = current; self.materials = materials
    }
}

public struct Proposal: Sendable, Codable, Equatable {
    public var parts: [Part]
    public var project: [String: String]
    public var products: [String]
    public var assumptions: [String]
    public var questions: [String]

    public init(parts: [Part], project: [String: String], products: [String], assumptions: [String], questions: [String]) {
        self.parts = parts; self.project = project; self.products = products
        self.assumptions = assumptions; self.questions = questions
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
}

public protocol Designer: Sendable {
    func design(_ brief: Brief) async throws -> Proposal
}
