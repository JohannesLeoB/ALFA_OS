import Foundation
import ImageIO

/// Whether the bytes of an image are a picture that ImageIO can read.
public enum PictureCheck {
    /// True when the bytes have at least one image and its properties can be read.
    public static func isPicture(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return false }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil
    }
}
