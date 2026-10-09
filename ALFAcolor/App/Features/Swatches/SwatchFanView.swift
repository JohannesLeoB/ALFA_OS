import AppTheme
import Motion
import SwiftUI
import Tokens

/// A colour fan: one blade per colour, riveted through one lower corner. A tap on the shut stack opens it,
/// a tap on the rivet closes it, and a tap on an open blade selects its colour. The geometry and the timing
/// come from `Motion`; this view only draws them with the theme.
struct SwatchFanView: View {
    let colors: [RGB]
    @Binding var selection: Int?

    @State private var stage: FanStage = .shut
    @State private var playing: Task<Void, Never>?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let shadowAlpha = 0.18
    private static let contactAlpha = 0.18
    private static let hairline: CGFloat = 1
    private static let selectionLine: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fan = FanGeometry.fitted(to: size, count: colors.count)
            let pivot = fan.pivot(for: stage, in: size)
            ZStack {
                ZStack {
                    ForEach(0..<colors.count, id: \.self) { index in
                        blade(index, fan: fan, size: size)
                    }
                }
                .compositingGroup()
                .shadow(color: theme.color(.text, scheme).opacity(Self.shadowAlpha),
                        radius: CGFloat(fan.shadowRadius), x: 0, y: CGFloat(fan.shadowOffset))

                rivet(fan: fan, at: pivot)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                tap(at: value.location, fan: fan, size: size)
            })
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Color fan"))
            .accessibilityAction { toggle() }
        }
        .onDisappear { playing?.cancel() }
    }

    // MARK: - Parts

    private func blade(_ index: Int, fan: FanGeometry, size: CGSize) -> some View {
        let anchor = fan.rivetInBlade
        let width = CGFloat(fan.bladeWidth)
        let length = CGFloat(fan.bladeLength)
        let pivot = fan.pivot(for: stage, in: size)
        let shape = RoundedRectangle(cornerRadius: CGFloat(fan.cornerRadius))
        let isSelected = selection == index
        let shade = fan.contactShade(at: stage)

        return shape
            .fill(Color(colors[index]))
            .overlay(shape.strokeBorder(
                isSelected ? theme.color(.accent, scheme) : theme.color(.border, scheme),
                lineWidth: isSelected ? Self.selectionLine : Self.hairline))
            .frame(width: width, height: length)
            .shadow(color: theme.color(.text, scheme).opacity(Self.contactAlpha * shade),
                    radius: CGFloat(fan.contactRadius), x: 0, y: CGFloat(fan.contactOffset))
            .overlay(alignment: .top) { codeLabel(index, gap: fan.labelGap, stage: stage) }
            .accessibilityLabel(Text(colors[index].hex))
            .rotationEffect(.degrees(fan.angle(of: index, at: stage)),
                            anchor: UnitPoint(x: fraction(anchor.x, width), y: fraction(anchor.y, length)))
            .position(x: pivot.x - anchor.x + width / 2, y: pivot.y - anchor.y + length / 2)
    }

    /// The hex code at the tip of the blade. It turns with the blade and shows only while the fan is open.
    private func codeLabel(_ index: Int, gap: Double, stage: FanStage) -> some View {
        Text(colors[index].hex)
            .font(theme.text(.caption).font)
            .foregroundStyle(theme.color(.textMuted, scheme))
            .fixedSize()
            .alignmentGuide(.top) { dimensions in dimensions[.bottom] + CGFloat(gap) }
            .opacity(stage == .open ? 1 : 0)
    }

    private func rivet(fan: FanGeometry, at pivot: CGPoint) -> some View {
        let diameter = CGFloat(fan.holeRadius * 2)
        return Circle()
            .fill(theme.color(.surface, scheme))
            .overlay(Circle().strokeBorder(theme.color(.border, scheme), lineWidth: Self.hairline))
            .frame(width: diameter, height: diameter)
            .position(pivot)
    }

    // MARK: - Actions

    private func tap(at location: CGPoint, fan: FanGeometry, size: CGSize) {
        switch (stage, fan.target(at: location, stage: stage, in: size)) {
        case (.shut, .nothing):
            break
        case (.shut, _):
            toggle()
        case (.open, .rivet):
            toggle()
        case (.open, .blade(let index)):
            selection = index
        default:
            break
        }
    }

    private func toggle() {
        guard let steps = FanMotion.toggled(from: stage) else { return }
        play(steps)
    }

    /// Runs the steps one after another. Each step animates to its stage over its own duration.
    private func play(_ steps: [FanStep]) {
        playing?.cancel()
        playing = Task { @MainActor in
            for step in steps {
                let milliseconds = step.effectiveMilliseconds(reduceMotion: reduceMotion)
                let curve = FanMotion.easing
                let animation: Animation? = reduceMotion
                    ? nil
                    : .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Double(milliseconds) / 1000)
                withAnimation(animation) {
                    stage = step.stage
                }
                try? await Task.sleep(for: .milliseconds(milliseconds))
                if Task.isCancelled { return }
            }
        }
    }

    /// A value over a length as a fraction, zero while the length is empty.
    private func fraction(_ value: CGFloat, _ length: CGFloat) -> CGFloat {
        length > 0 ? value / length : 0
    }
}
