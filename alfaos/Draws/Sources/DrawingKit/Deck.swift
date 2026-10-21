import CoreGraphics
import Foundation
import Pages

extension Composer {
    func caps(_ text: String) -> String {
        r.template.deck?.caps == true ? text.uppercased() : text
    }

    mutating func zone(_ name: String, _ rect: CGRect, _ item: Item) {
        let page = PageTemplate(size: CGSize(width: sheet.width, height: sheet.height), zones: [name: rect])
        let filled = fill(page, [name: [item]], fonts: sheet.faces)
        sheet.items += filled.page.items.map(SheetItem.raw)
        if !filled.overflow.isEmpty, !sheet.defects.contains("deck.\(name)") { sheet.defects.append("deck.\(name)") }
    }

    mutating func furniture(cover: Bool) {
        guard let d = r.template.deck else { return }
        let v = values(), ci = r.ci
        let title = v[d.titleKey] ?? v["project"] ?? ""
        if !title.isEmpty {
            zone("title", CGRect(x: d.titleX, y: d.titleTop, width: d.titleWidth, height: d.titleHeight),
                 .textBlock(Block(title, frame: CGRect(x: 0, y: 0, width: d.titleWidth, height: d.titleHeight),
                                  size: ci.textDeck, color: ci.ink, leading: d.titleLeading)))
        }
        put(caps(cover ? (v["date"] ?? "") : (v["page"] ?? "")), at: CGPoint(x: d.headX, y: d.headBase),
            size: ci.textCaption, mono: true, anchor: .end)
        if !cover {
            for f in d.foot {
                put(caps(expand(f.text, v)), at: CGPoint(x: f.x, y: d.footBase), size: ci.textCaption, mono: true,
                    anchor: f.end ? .end : .start)
            }
        }
        logo(cover: cover)
    }

    mutating func caption(_ cell: Cell) {
        guard let d = r.template.deck, let text = r.project["caption.\(cell.id)"], !text.isEmpty else { return }
        let rect = CGRect(x: cell.frame.minX, y: cell.frame.maxY + d.captionGap, width: cell.frame.width, height: d.captionLeading * 4)
        zone("caption.\(cell.id)", rect,
             .textBlock(Block(caps(text), frame: CGRect(origin: .zero, size: rect.size), size: r.ci.textCaption,
                              color: r.ci.ink, leading: d.captionLeading, role: .mono)))
    }
}
