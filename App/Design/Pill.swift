import SwiftUI

struct Pill: InsettableShape {
    var inset = CGFloat.zero

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        guard box.width > box.height else { return Path(ellipseIn: box) }
        let radius = box.height / 2
        var path = Path()
        path.move(to: CGPoint(x: box.minX + radius, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - radius, y: box.minY))
        path.addArc(center: CGPoint(x: box.maxX - radius, y: box.midY), radius: radius, startAngle: .degrees(-SheetValues.quarterTurn), endAngle: .degrees(SheetValues.quarterTurn), clockwise: false)
        path.addLine(to: CGPoint(x: box.minX + radius, y: box.maxY))
        path.addArc(center: CGPoint(x: box.minX + radius, y: box.midY), radius: radius, startAngle: .degrees(SheetValues.quarterTurn), endAngle: .degrees(SheetValues.halfTurn + SheetValues.quarterTurn), clockwise: false)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Pill {
        Pill(inset: inset + amount)
    }
}
