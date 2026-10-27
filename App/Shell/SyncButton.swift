import Core
import Design
import Shell
import SwiftUI

struct SyncButton: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var turn = 0.0

    var body: some View {
        let failed = session.syncFailed
        let profile = session.settings.profile
        let face = Initials.avatar(code: profile.code, name: profile.name)
        let title = session.syncing ? "sync.running" : failed ? "sync.failed" : "sync.fresh"
        let ring = CGFloat(Tokens.Size.symbolSize)
        let line = CGFloat(Tokens.Size.hairline)
        Button(action: run) {
            ZStack {
                Text(verbatim: face)
                    .font(.face(Tokens.TextSize.blobFace, weight: Tokens.Weight.medium))
                    .tracking(CGFloat(SheetValues.initialsTracking * Tokens.TextSize.blobFace))
                Circle()
                    .strokeBorder(.foreground, lineWidth: line)
                    .opacity(Tokens.Opacity.ringOnColor)
                Circle()
                    .inset(by: line / 2)
                    .trim(from: 0, to: failed ? CGFloat(SheetValues.syncErrorArc) : 1)
                    .stroke(failed ? AnyShapeStyle(appearance.color(\.signal)) : AnyShapeStyle(.foreground), lineWidth: line)
                    .rotationEffect(.degrees(SheetValues.syncArcStart + turn))
            }
            .frame(width: ring, height: ring)
            .padding(.horizontal, CGFloat(Tokens.Spacing.blobInset))
            .frame(width: CGFloat(Tokens.Size.blobWidth), height: CGFloat(Tokens.Size.blobHeight), alignment: .trailing)
            .foregroundStyle(appearance.color(\.onInverse))
            .background(Capsule().fill(appearance.color(\.inverse)))
            .overlay(alignment: .topLeading) {
                if failed {
                    Circle()
                        .fill(appearance.color(\.signal))
                        .frame(width: CGFloat(Tokens.Spacing.statusDot), height: CGFloat(Tokens.Spacing.statusDot))
                        .padding(.top, CGFloat(Tokens.Spacing.blobInset))
                        .padding(.leading, CGFloat(Tokens.Spacing.step12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadowLayers(Capsule())
        .help(appearance.string(title))
        .accessibilityLabel(appearance.text(title))
    }

    private func run() {
        guard !session.syncing else { return }
        if let spin = appearance.ease(Tokens.Duration.syncSpin) {
            withAnimation(spin) { turn += SheetValues.syncSweep }
        }
        Task { await session.sync() }
    }
}
