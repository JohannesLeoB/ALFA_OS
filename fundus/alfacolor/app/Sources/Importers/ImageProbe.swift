import Foundation
import ImageIO
import UniformTypeIdentifiers
import BoardModel

/// Reads facts from image bytes without decoding the picture.
enum ImageProbe {
    /// The size in pixels as the picture is shown, with the turn from the metadata applied. nil when the bytes are no image.
    static func pixelSize(of data: Data) -> CanvasSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (info[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (info[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else { return nil }
        let turn = (info[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(turn) ? CanvasSize(width: height, height: width) : CanvasSize(width: width, height: height)
    }

    /// PNG bytes of an image in another format, or nil when the bytes cannot be read.
    static func pngData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let out = NSMutableData()
        guard let target = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(target, image, nil)
        return CGImageDestinationFinalize(target) ? out as Data : nil
    }
}
