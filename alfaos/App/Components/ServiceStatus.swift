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
            .ring(Circle(), design.color(border))
            label
                .lineLimit(1)
                .padding(.trailing, trailingInset ? CGFloat(Design.Size.trailingTextInset) : 0)
        }
        .font(.face(Design.TextSize.small))
        .foregroundStyle(design.color(foreground))
    }
}
