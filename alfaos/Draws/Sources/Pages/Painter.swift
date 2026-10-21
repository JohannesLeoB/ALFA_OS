import CoreGraphics
import CoreText
import Foundation
import ImageIO

public enum Painter {
    public static func draw(_ page: Page, fonts: [FontFace], in ctx: CGContext) {
        if let background = page.background {
            ctx.setFillColor(Tint.cg(background))
            ctx.fill(CGRect(origin: .zero, size: page.size))
        }
        ctx.setLineJoin(.round)
        for item in page.items { draw(item, fonts, ctx) }
    }

    static func draw(_ item: Item, _ fonts: [FontFace], _ ctx: CGContext) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        switch item {
        case let .line(a, b, paint):
            let path = CGMutablePath()
            path.addLines(between: [a, b])
            shape(path, paint, ctx, about: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), turn: false)
        case let .rect(r, paint):
            shape(CGPath(rect: r, transform: nil), paint, ctx, about: CGPoint(x: r.midX, y: r.midY), turn: true)
        case let .polygon(points, paint):
            guard points.count > 2 else { return }
            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            shape(path, paint, ctx, about: Metrics.center(points.map(Step.line)), turn: true)
        case let .path(steps, paint):
            let path = CGMutablePath()
            for step in steps {
                switch step {
                case let .move(p): path.move(to: p)
                case let .line(p): path.addLine(to: p)
                case let .curve(a, b, c): path.addCurve(to: c, control1: a, control2: b)
                case .close: path.closeSubpath()
                }
            }
            shape(path, paint, ctx, about: Metrics.center(steps), turn: true)
        case let .text(run):
            let line = Typeset.line(run, fonts)
            let shift = Typeset.shift(run.anchor, Typeset.width(line))
            ctx.translateBy(x: run.origin.x, y: run.origin.y)
            ctx.rotate(by: run.rotation * .pi / 180)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = CGPoint(x: shift, y: 0)
            CTLineDraw(line, ctx)
        case let .textBlock(block):
            for laid in Typeset.lay(block, fonts).lines {
                ctx.saveGState()
                ctx.translateBy(x: laid.x, y: laid.y)
                ctx.scaleBy(x: 1, y: -1)
                ctx.textPosition = .zero
                CTLineDraw(laid.line, ctx)
                ctx.restoreGState()
            }
        case let .image(picture):
            guard let data = picture.bytes, let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            let fit = aspect(CGSize(width: image.width, height: image.height), picture.frame)
            ctx.setAlpha(CGFloat(min(1, max(0, picture.opacity))))
            ctx.translateBy(x: fit.minX, y: fit.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: fit.width, height: fit.height))
        case let .group(transform, items):
            ctx.translateBy(x: transform.dx, y: transform.dy)
            ctx.rotate(by: transform.rotation * .pi / 180)
            ctx.scaleBy(x: transform.scale, y: transform.scale)
            if let clip = transform.clip { ctx.clip(to: clip) }
            for child in items { draw(child, fonts, ctx) }
        }
    }

    static func shape(_ path: CGPath, _ paint: Paint, _ ctx: CGContext, about c: CGPoint, turn: Bool) {
        if turn, paint.rotation != 0 {
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: paint.rotation * .pi / 180)
            ctx.translateBy(x: -c.x, y: -c.y)
        }
        if !paint.dash.isEmpty { ctx.setLineDash(phase: 0, lengths: paint.dash.map { CGFloat($0) }) }
        if let fill = paint.fill {
            ctx.addPath(path)
            ctx.setFillColor(Tint.cg(fill))
            ctx.fillPath()
        }
        if let stroke = paint.stroke {
            ctx.addPath(path)
            ctx.setStrokeColor(Tint.cg(stroke))
            ctx.setLineWidth(paint.width)
            ctx.strokePath()
        }
    }

    static func aspect(_ image: CGSize, _ frame: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0 else { return frame }
        let k = min(frame.width / image.width, frame.height / image.height)
        let size = CGSize(width: image.width * k, height: image.height * k)
        return CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height)
    }
}
