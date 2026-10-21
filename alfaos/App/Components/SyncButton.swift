import ShellCore
import SwiftUI

struct SyncButton: View {
    let theme: Theme
    let host: AppHost?
    @State private var turn = 0.0
    @AppStorage(SettingsKey.identityName) private var name = ""
    @AppStorage(SettingsKey.identityCode) private var code = ""

    var body: some View {
        let failed = host?.syncFailed ?? false
        let face = Initials.avatar(code: code, name: name)
        let title = host?.syncing == true ? "sync.running" : failed ? "sync.failed" : "sync.fresh"
        let ring = CGFloat(Design.Size.symbolSize)
        let line = CGFloat(Design.Size.hairline)
        Button(action: run) {
            ZStack {
                Text(verbatim: face)
                    .font(theme.font(Design.TextSize.blobFace, weight: Design.Weight.medium))
                    .tracking(CGFloat(SheetValues.initialsTracking * Design.TextSize.blobFace))
                Circle()
                    .strokeBorder(.foreground, lineWidth: line)
                    .opacity(Design.Opacity.ringOnColor)
                Circle()
                    .inset(by: line / 2)
                    .trim(from: 0, to: failed ? CGFloat(SheetValues.syncErrorArc) : 1)
                    .stroke(failed ? AnyShapeStyle(theme.design(\.signal)) : AnyShapeStyle(.foreground), lineWidth: line)
                    .rotationEffect(.degrees(SheetValues.syncArcStart + turn))
            }
            .frame(width: ring, height: ring)
            .padding(.horizontal, CGFloat(Design.Spacing.blobInset))
            .frame(width: CGFloat(Design.Size.blobWidth), height: CGFloat(Design.Size.blobHeight), alignment: .trailing)
            .foregroundStyle(theme.design(\.onInverse))
            .background(Capsule().fill(theme.design(\.inverse)))
            .overlay(alignment: .topLeading) {
                if failed {
                    Circle()
                        .fill(theme.design(\.signal))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .padding(.top, CGFloat(Design.Spacing.blobInset))
                        .padding(.leading, CGFloat(Design.Spacing.step12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .themeShadow(theme, layers: theme.designShadow(\.floating), shape: Capsule())
        .help(theme.string(title))
        .accessibilityLabel(theme.text(title))
    }

    private func run() {
        guard let host, !host.syncing else { return }
        if let spin = theme.ease(Design.Duration.syncSpin) {
            withAnimation(spin) { turn += SheetValues.syncSweep }
        }
        Task { await host.sync() }
    }
}
