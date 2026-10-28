import Design
import SwiftUI

struct EnvelopeStack: View {
    @Environment(\.appearance) private var appearance
    let open: Bool

    var body: some View {
        let box = CGFloat(SheetValues.envelopeBox)
        ZStack(alignment: .topLeading) {
            ForEach([2, 1, 0], id: \.self) { index in
                envelope(flap: index == 0)
                    .offset(x: CGFloat((open ? SheetValues.envelopeOpenX : SheetValues.envelopeShutX)[index]),
                            y: CGFloat((open ? SheetValues.envelopeOpenY : SheetValues.envelopeShutY)[index]))
                    .animation(appearance.ease(SheetValues.envelopeTimes[index], Tokens.Easing.envelopeSpring,
                                               delay: (open ? SheetValues.envelopeOpenDelays : SheetValues.envelopeShutDelays)[index]),
                               value: open)
            }
        }
        .frame(width: box, height: box, alignment: .topLeading)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: CGFloat(Tokens.Size.envelopeStroke), lineCap: .round, lineJoin: .round)
    }

    private func envelope(flap: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(SheetValues.envelopeRadius))
        let inset = CGFloat(SheetValues.envelopeFlapInset)
        return ZStack(alignment: .topLeading) {
            shape.fill(appearance.color(\.lane))
            shape.stroke(style: stroke)
            if flap {
                EnvelopeFlap()
                    .stroke(style: stroke)
                    .frame(width: CGFloat(SheetValues.envelopeWidth) - inset * 2, height: CGFloat(SheetValues.envelopeFlapDepth))
                    .scaleEffect(x: 1, y: open ? -1 : 1, anchor: .top)
                    .offset(x: inset, y: CGFloat(SheetValues.envelopeFlapTop))
                    .animation(open
                               ? appearance.ease(Tokens.Duration.flapOpen, Tokens.Easing.envelopeSpring, delay: Tokens.Duration.flapOpenDelay)
                               : appearance.ease(Tokens.Duration.flapClose, Tokens.Easing.deckClose),
                               value: open)
            }
        }
        .frame(width: CGFloat(SheetValues.envelopeWidth), height: CGFloat(SheetValues.envelopeHeight), alignment: .topLeading)
    }
}

private struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
