import Foundation

/// One request to the Messages API.
public struct AIRequest: Sendable, Equatable {
    public var model: String
    public var system: String
    public var messages: [AIMessage]
    public var maxTokens: Int
    public var temperature: Double?

    public init(model: String, system: String, messages: [AIMessage], maxTokens: Int, temperature: Double? = nil) {
        self.model = model
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

/// One turn of a conversation.
public struct AIMessage: Sendable, Equatable {
    public enum Role: String, Sendable, Equatable {
        case user
        case assistant
    }

    public var role: Role
    public var blocks: [AIBlock]

    public init(role: Role, blocks: [AIBlock]) {
        self.role = role
        self.blocks = blocks
    }
}

/// One part of a message: text or an image.
public enum AIBlock: Sendable, Equatable {
    case text(String)
    case image(AIImage)
}

/// The image formats that the API takes.
public enum ImageMediaType: String, Sendable, Equatable, CaseIterable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case gif = "image/gif"
    case webp = "image/webp"
}

/// An image with its pixel size. The caller states the size; this module does not decode images.
public struct AIImage: Sendable, Equatable {
    public var data: Data
    public var mediaType: ImageMediaType
    public var width: Int
    public var height: Int

    public init(data: Data, mediaType: ImageMediaType, width: Int, height: Int) {
        self.data = data
        self.mediaType = mediaType
        self.width = width
        self.height = height
    }
}

/// The answer of the API, reduced to what the app uses.
public struct AIResponse: Sendable, Equatable {
    public var text: String
    public var stopReason: String?
    public var usage: AIUsage
    public var model: String
    public var requestID: String?

    public init(text: String, stopReason: String?, usage: AIUsage, model: String, requestID: String?) {
        self.text = text
        self.stopReason = stopReason
        self.usage = usage
        self.model = model
        self.requestID = requestID
    }
}

/// The tokens of one call, as the API counts them.
public struct AIUsage: Sendable, Equatable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int

    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheReadTokens: Int = 0, cacheWriteTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
    }
}
