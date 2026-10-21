import CoreGraphics
import Foundation

public struct PageTemplate: Sendable {
    public var size: CGSize
    public var background: String?
    public var zones: [String: CGRect]
    public var fixed: [Item]

    public init(size: CGSize, background: String? = nil, zones: [String: CGRect] = [:], fixed: [Item] = []) {
        self.size = size; self.background = background; self.zones = zones; self.fixed = fixed
    }
}

public struct Overflow: Sendable, Equatable, CustomStringConvertible {
    public enum Kind: String, Sendable { case bounds, text, zone }

    public var zone: String
    public var index: Int
    public var kind: Kind

    public var description: String { "\(zone)#\(index):\(kind.rawValue)" }
}

public struct Filled: Sendable {
    public var page: Page
    public var overflow: [Overflow]
}

public func fill(_ template: PageTemplate, _ content: [String: [Item]], fonts: [FontFace] = []) -> Filled {
    var items = template.fixed
    var overflow: [Overflow] = []
    for name in content.keys.sorted() {
        let entries = content[name] ?? []
        guard let zone = template.zones[name] else {
            overflow.append(Overflow(zone: name, index: -1, kind: .zone))
            continue
        }
        let local = CGRect(origin: .zero, size: zone.size).insetBy(dx: -0.01, dy: -0.01)
        for (index, item) in entries.enumerated() {
            if let box = Metrics.bounds(item, fonts), !local.contains(box) {
                overflow.append(Overflow(zone: name, index: index, kind: .bounds))
            }
            if case let .textBlock(block) = item, !Typeset.lay(block, fonts).fits {
                overflow.append(Overflow(zone: name, index: index, kind: .text))
            }
        }
        items.append(.group(Transform(dx: zone.minX, dy: zone.minY, clip: CGRect(origin: .zero, size: zone.size)), entries))
    }
    return Filled(page: Page(size: template.size, background: template.background, items: items), overflow: overflow)
}
