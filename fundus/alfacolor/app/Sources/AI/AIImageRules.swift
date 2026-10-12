import Foundation

/// The limits that an image must keep before it goes to the API.
public enum AIImageRules {
    /// The largest size of an image as base64 text, in bytes.
    public static let maxBase64Bytes = 5 * 1024 * 1024
    /// The largest width or height in pixels.
    public static let maxSide = 8000

    /// Throws `AIError.imageRejected` when the image breaks a limit.
    public static func check(_ image: AIImage) throws {
        guard !image.data.isEmpty else {
            throw AIError.imageRejected("empty image")
        }
        guard image.width >= 1, image.height >= 1 else {
            throw AIError.imageRejected("no pixel size")
        }
        guard image.width <= maxSide, image.height <= maxSide else {
            throw AIError.imageRejected("pixel size above \(maxSide) px")
        }
        guard base64Length(of: image.data.count) <= maxBase64Bytes else {
            throw AIError.imageRejected("image above 5 MB as base64")
        }
    }

    /// The number of characters that base64 text of this many bytes takes, with padding.
    public static func base64Length(of byteCount: Int) -> Int {
        ((byteCount + 2) / 3) * 4
    }
}
