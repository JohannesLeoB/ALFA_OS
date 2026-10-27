import Design
import Shell
import SwiftUI

struct ThinkingOrb: View {
    @Environment(\.appearance) private var appearance
    let size: Double
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: appearance.still)) { context in
            orb(elapsed: appearance.still ? 0 : context.date.timeIntervalSince(start))
        }
    }

    private func orb(elapsed: Double) -> some View {
        let side = CGFloat(size)
        let spot = side * CGFloat(SheetValues.orbSpot)
        let orbits = [Tokens.Duration.orbOrbitFirst, Tokens.Duration.orbOrbitSecond, Tokens.Duration.orbOrbitThird]
        let colors = [appearance.mood(\.coral), appearance.mood(\.apricot), appearance.mood(\.rose)]
        let reach = appearance.still ? 0 : Double(spot) * SheetValues.orbOrbit
        return ZStack {
            appearance.color(\.orb)
            ForEach(0..<SheetValues.orbCount, id: \.self) { index in
                let direction: Double = index == 1 ? -1 : 1
                let angle = 2 * Double.pi * elapsed / orbits[index] * direction
                Circle()
                    .fill(colors[index])
                    .frame(width: spot, height: spot)
                    .blur(radius: CGFloat(Tokens.Size.orbGlowBlur))
                    .blendMode(.screen)
                    .offset(x: CGFloat(cos(angle) * reach), y: CGFloat(sin(angle) * reach))
            }
            RadialGradient(
                colors: [appearance.color(\.orbGloss), appearance.color(\.orbGloss).opacity(0)],
                center: UnitPoint(x: SheetValues.orbGlossX, y: SheetValues.orbGlossY),
                startRadius: 0,
                endRadius: glossRadius(side)
            )
        }
        .compositingGroup()
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(appearance.color(\.orbRim), lineWidth: CGFloat(Tokens.Size.hairline)))
    }

    private func glossRadius(_ side: CGFloat) -> CGFloat {
        let rx = 2.0.squareRoot() * max(SheetValues.orbGlossX, 1 - SheetValues.orbGlossX)
        let ry = 2.0.squareRoot() * max(SheetValues.orbGlossY, 1 - SheetValues.orbGlossY)
        return side * CGFloat(SheetValues.orbGlossStop * (rx + ry) / 2)
    }
}
