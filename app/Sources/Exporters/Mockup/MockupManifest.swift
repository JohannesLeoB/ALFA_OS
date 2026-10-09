import Foundation

/// manifest.json of a mockup package. Positions are points; the origin is the top left corner of the frame,
/// or of the free sheet for items without a frame.
struct MockupManifest: Codable, Equatable {
    var format = "alfacolor-mockup/1"
    var title: String
    var created: String
    var frames: [Frame]
    var items: [Entry]
    var warnings: [String]

    struct Frame: Codable, Equatable {
        var id: String
        var title: String
        var width: Double
        var height: Double
    }

    struct Entry: Codable, Equatable {
        var id: String
        var type: String
        var title: String
        /// The frame the item lies on. Null on the free sheet.
        var frame: String?
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var z: Int
        /// The layer of the item. The entries are in canvas order: by layer rank, then by z.
        var layer: String? = nil
        var mode: String? = nil
        var file: String? = nil
        var tokens: [String] = []
        var text: String? = nil
        var previewWidth: Double? = nil
        var color: String? = nil
        var fill: String? = nil
        var stroke: String? = nil
        var url: String? = nil
        var license: String? = nil
        var via: String? = nil

        enum CodingKeys: String, CodingKey {
            case id, type, title, frame, x, y, width, height, z, layer, mode, file, tokens, text, previewWidth
            case color, fill, stroke, url, license, via
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(type, forKey: .type)
            try c.encode(title, forKey: .title)
            try c.encode(frame, forKey: .frame)
            try c.encode(x, forKey: .x)
            try c.encode(y, forKey: .y)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(z, forKey: .z)
            try c.encodeIfPresent(layer, forKey: .layer)
            try c.encodeIfPresent(mode, forKey: .mode)
            try c.encodeIfPresent(file, forKey: .file)
            try c.encode(tokens, forKey: .tokens)
            try c.encodeIfPresent(text, forKey: .text)
            try c.encodeIfPresent(previewWidth, forKey: .previewWidth)
            try c.encodeIfPresent(color, forKey: .color)
            try c.encodeIfPresent(fill, forKey: .fill)
            try c.encodeIfPresent(stroke, forKey: .stroke)
            try c.encodeIfPresent(url, forKey: .url)
            try c.encodeIfPresent(license, forKey: .license)
            try c.encodeIfPresent(via, forKey: .via)
        }
    }
}
