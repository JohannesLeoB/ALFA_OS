import ShellCore
import SwiftUI

enum ServiceState {
    case connected
    case stored
    case connecting
    case working
    case notConnected
    case failed
    case unreadable
    case orphaned
}

struct ServiceStatus: View {
    @Environment(\.design) private var design
    let state: ServiceState
    let label: Text
    var inverted = false
    var trailingInset = false

    private var ink: InkSet { .of(inverted) }

    private var dotFill: KeyPath<DesignColors, RGB>? {
        switch state {
        case .connected, .stored: ink.primary
        case .failed: \.signal
        default: nil
        }
    }

    private var border: KeyPath<DesignColors, RGB> {
        switch state {
        case .connected, .stored: ink.primary
        case .connecting, .working, .notConnected: ink.line
        case .failed, .unreadable: \.signal
        case .orphaned: ink.tertiary
        }
    }

    private var foreground: KeyPath<DesignColors, RGB> {
        switch state {
        case .connected, .stored, .connecting, .working: ink.secondary
        case .notConnected, .orphaned: inverted ? ink.secondary : ink.tertiary
        case .failed, .unreadable: \.signal
        }
    }

    private var spins: Bool { state == .connecting || state == .working }

    var body: some View {
        let dot = CGFloat(Design.Spacing.statusDot)
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            ZStack(alignment: .leading) {
                if let dotFill {
                    Circle()
                        .fill(design.color(dotFill))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: state == .stored ? dot / 2 : dot)
                        }
                }
            }
            .frame(width: dot, height: dot)
            .overlay {
                if state == .orphaned {
                    Circle().strokeBorder(design.color(border), style: StrokeStyle(lineWidth: CGFloat(Design.Size.hairline),
                                                                                 dash: SheetValues.dashedLine.map { CGFloat($0) }))
                } else {
                    Circle().strokeBorder(design.color(border), lineWidth: CGFloat(Design.Size.hairline))
                }
            }
            .overlay { if spins { StatusArc() } }
            label
                .lineLimit(1)
                .padding(.trailing, trailingInset ? CGFloat(Design.Size.trailingTextInset) : 0)
        }
        .font(.face(Design.TextSize.small))
        .foregroundStyle(design.color(foreground))
    }
}

private struct StatusArc: View {
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var turn = 0.0

    var body: some View {
        let side = CGFloat(SheetValues.statusArcBox)
        Circle()
            .trim(from: 0, to: CGFloat(SheetValues.statusArc))
            .stroke(.foreground, style: StrokeStyle(lineWidth: CGFloat(SheetValues.iconStroke), lineCap: .round))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(turn))
            .task {
                guard !reduced else { return }
                withAnimation(.linear(duration: Design.Duration.thinking).repeatForever(autoreverses: false)) { turn = SheetValues.fullTurn }
            }
    }
}
