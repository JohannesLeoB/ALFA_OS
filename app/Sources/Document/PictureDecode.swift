import Foundation
import CoreGraphics
import ImageIO

/// Decodes the bytes of a picture into a small bitmap for colour work. ImageIO lives here, not in the colour code.
public enum PictureDecode {
    /// The longest side of the bitmap in pixels. Colour extraction works on a small grid, so more is not needed.
    public static let maxSide = 256

    /// The picture as a bitmap whose longest side is at most `maxSide`, turned as the picture shows it.
    /// Nil when the bytes are not a picture.
    public static func image(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
