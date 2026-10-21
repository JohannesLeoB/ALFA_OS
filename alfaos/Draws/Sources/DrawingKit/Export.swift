import CoreGraphics
import Foundation
import Pages

public enum SheetExporter {
    public static func svg(_ s: Sheet) -> Data {
        Data(SVGRenderer().svg(s.page, fonts: s.faces).utf8)
    }

    public static func pdf(_ s: Sheet) -> Data {
        pdf([s])
    }

    public static func pdf(_ sheets: [Sheet]) -> Data {
        PDFRenderer().render(Document(pages: sheets.map(\.page), fonts: sheets.first?.faces ?? []))
    }

    public static func draw(_ s: Sheet, in ctx: CGContext) {
        Painter.draw(s.page, fonts: s.faces, in: ctx)
    }
}
