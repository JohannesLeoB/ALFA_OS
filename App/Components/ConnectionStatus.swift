import Design
import Shell
import SwiftUI

enum ConnectionState {
    case connected
    case stored
    case connecting
    case working
    case notConnected
    case failed
    case unreadable
    case orphaned
}

struct ConnectionStatus: View {
    @Environment(\.appearance) private var appearance
    let state: ConnectionState
    let label: Text
    var inverted = false

    private var ink: InkSet { .of(inverted) }

    private var dotFill: KeyPath<Colors, ColorValue>? {
        switch state {
        case .connected, .stored: ink.primary
        case .failed: \.signal
        default: nil
        }
    }

    private var border: KeyPath<Colors, ColorValue> {
        switch state {
        case .connected, .stored: ink.primary
        case .connecting, .working, .notConnected: ink.line
        case .failed, .unreadable: \.signal
        case .orphaned: ink.tertiary
        }
    }

    private var foreground: KeyPath<Colors, ColorValue> {
        switch state {
        case .connected, .stored, .connecting, .working: ink.secondary
        case .notConnected, .orphaned: inverted ? ink.secondary : ink.tertiary
        case .failed, .unreadable: \.signal
        }
    }

    private var spins: Bool { state == .connecting || state == .working }

    var body: some View {
        let dot = CGFloat(Tokens.Spacing.statusDot)
        let line = CGFloat(Tokens.Size.hairline)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            ZStack(alignment: .leading) {
                if let dotFill {
                    Circle()
                        .fill(appearance.color(dotFill))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: state == .stored ? dot / 2 : dot)
                        }
                }
            }
            .frame(width: dot, height: dot)
            .overlay {
                if state == .orphaned {
                    Circle().strokeBorder(appearance.color(border), style: StrokeStyle(lineWidth: line, dash: SheetValues.dashedLine.map { CGFloat($0) }))
                } else {
                    Circle().strokeBorder(appearance.color(border), lineWidth: line)
                }
            }
            .overlay {
                if spins {
                    Spinner(side: SheetValues.statusArcBox, arc: SheetValues.statusArc, stroke: SheetValues.iconStroke,
                            tone: nil, round: true)
                }
            }
            label
                .lineLimit(1)
                .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
        }
        .font(.face(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(foreground))
    }
}
