import Design
import Shell
import SwiftUI

enum ConnectionState {
    case connected
    case connecting
    case working
    case notConnected
    case failed
    case unreadable
}

struct ConnectionStatus: View {
    @Environment(\.appearance) private var appearance
    let state: ConnectionState
    let label: Text
    var inverted = false

    private var ink: InkSet { .of(inverted) }

    private var dotFill: KeyPath<Colors, ColorValue>? {
        switch state {
        case .connected: ink.primary
        case .failed: \.signal
        default: nil
        }
    }

    private var border: KeyPath<Colors, ColorValue> {
        switch state {
        case .connected: ink.primary
        case .connecting, .working, .notConnected: ink.line
        case .failed, .unreadable: \.signal
        }
    }

    private var foreground: KeyPath<Colors, ColorValue> {
        switch state {
        case .connected, .connecting, .working: ink.secondary
        case .notConnected: inverted ? ink.secondary : ink.tertiary
        case .failed, .unreadable: \.signal
        }
    }

    private var spins: Bool { state == .connecting || state == .working }

    var body: some View {
        let dot = CGFloat(Tokens.Spacing.statusDot)
        let line = CGFloat(Tokens.Size.hairline)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            ZStack {
                if let dotFill {
                    Circle().fill(appearance.color(dotFill))
                }
            }
            .frame(width: dot, height: dot)
            .overlay {
                Circle().strokeBorder(appearance.color(border), lineWidth: line)
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
