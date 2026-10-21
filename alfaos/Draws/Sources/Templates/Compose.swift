import CoreGraphics
import Foundation
import ImageIO
import Pages

public struct Unfit: Sendable, Equatable, CustomStringConvertible {
    public enum Reason: String, Sendable { case zone, text, style, image }

    public var page: Int
    public var zone: String
    public var reason: Reason

    public var description: String { "\(page):\(zone):\(reason.rawValue)" }
}

public struct Composed: Sendable {
    public var document: Document
    public var unfit: [Unfit]
}

enum Place {
    static func pixels(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    static func item(_ data: Data, _ pixels: CGSize, _ zone: Zone) -> Item {
        let box = zone.rect
        let fill = (zone.fit ?? .fill) == .fill
        let ratios = [box.width / pixels.width, box.height / pixels.height]
        let k = (fill ? ratios.max() : ratios.min()) ?? 1
        let size = CGSize(width: pixels.width * k, height: pixels.height * k)
        let picture = Item.image(Picture(data: data, frame: CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height)))
        return fill ? .group(Transform(clip: box), [picture]) : picture
    }

    static func block(_ text: String, _ zone: Zone, _ ink: Ink) -> Item {
        .textBlock(Block(text, frame: CGRect(origin: .zero, size: zone.rect.size), size: ink.size, weight: ink.weight ?? 400, color: ink.color,
                         leading: ink.leading ?? 0, align: Align(rawValue: ink.align ?? "") ?? .left))
    }
}

public func compose(_ canvas: Canvas, images: [Data], texts: [String: String] = [:], fonts: [FontFace] = []) -> Composed {
    var unfit: [Unfit] = []
    let valid = canvas.zones.filter { $0.w > 0 && $0.h > 0 }
    for zone in canvas.zones where !valid.contains(zone) { unfit.append(Unfit(page: 1, zone: zone.name, reason: .zone)) }
    let slots = valid.filter { $0.role == .image }
    let writable = valid.filter { $0.role != .image }
    for name in texts.keys.sorted() where !writable.contains(where: { $0.name == name }) { unfit.append(Unfit(page: 1, zone: name, reason: .zone)) }
    var usable: [(Data, CGSize)] = []
    for (index, data) in images.enumerated() {
        if let size = Place.pixels(data) { usable.append((data, size)) } else { unfit.append(Unfit(page: 0, zone: "#\(index)", reason: .image)) }
    }
    if slots.isEmpty {
        for index in usable.indices { unfit.append(Unfit(page: 0, zone: "#\(index)", reason: .zone)) }
        usable = []
    }
    let count = max(1, slots.isEmpty ? 1 : (usable.count + slots.count - 1) / slots.count)
    var pages: [Page] = []
    for number in 0..<count {
        var items: [Item] = []
        for (offset, slot) in slots.enumerated() where number * slots.count + offset < usable.count {
            let picked = usable[number * slots.count + offset]
            items.append(Place.item(picked.0, picked.1, slot))
        }
        if number == 0 {
            var content: [String: [Item]] = [:]
            for zone in writable {
                guard let text = texts[zone.name] else { continue }
                guard let ink = zone.ink else { unfit.append(Unfit(page: 1, zone: zone.name, reason: .style)); continue }
                content[zone.name] = [Place.block(text, zone, ink)]
            }
            let frame = PageTemplate(size: CGSize(width: canvas.width, height: canvas.height), zones: Dictionary(writable.map { ($0.name, $0.rect) }, uniquingKeysWith: { first, _ in first }))
            let filled = fill(frame, content, fonts: fonts)
            items += filled.page.items
            for over in filled.overflow { unfit.append(Unfit(page: 1, zone: over.zone, reason: over.kind == .zone ? .zone : .text)) }
        }
        pages.append(Page(size: CGSize(width: canvas.width, height: canvas.height), background: canvas.background, items: items))
    }
    return Composed(document: Document(pages: pages, fonts: fonts), unfit: unfit)
}
