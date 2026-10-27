import Design
import Shell
import SwiftUI

enum LidKind: Equatable {
    case blink
    case wink
}

struct LidMotion: Equatable {
    let kind: LidKind?
    let serial: Int

    static let idle = LidMotion(kind: nil, serial: 0)

    static func start(_ kind: LidKind) -> LidMotion {
        LidMotion(kind: kind, serial: Int.random(in: 1..<Int.max))
    }
}

struct BlobEyes: View {
    @Environment(\.appearance) private var appearance
    let ring: Bool
    let open: Bool
    let follow: CGSize
    let lid: LidMotion
    @State private var progress = 1.0

    var body: some View {
        let size = CGFloat(Tokens.Size.symbolSize)
        HStack(spacing: CGFloat(Tokens.Size.blobEyeGap)) {
            eye
            eye
        }
        .lidShift(
            progress: progress,
            kind: lid.kind,
            scale: open ? 1 : SheetValues.lidRestScale,
            shift: open ? 0 : Tokens.Size.blobLidOffset
        )
        .animation(appearance.ease(Tokens.Duration.blobEyes), value: open)
        .offset(follow)
        .animation(nil, value: follow)
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.foreground, lineWidth: CGFloat(Tokens.Size.hairline)).opacity(ring ? 1 : 0))
        .onChange(of: lid) { _, next in run(next) }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.stroke))
            .fill(.foreground)
            .frame(width: CGFloat(Tokens.Size.blobEyeWidth), height: CGFloat(Tokens.Size.blobEyeHeight))
    }

    private func run(_ motion: LidMotion) {
        guard let kind = motion.kind else { return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        let animation: Animation = kind == .blink
            ? .linear(duration: Tokens.Duration.blobBlinkClose)
            : .timingCurve(Tokens.Easing.standard.x1, Tokens.Easing.standard.y1, Tokens.Easing.standard.x2, Tokens.Easing.standard.y2, duration: Tokens.Duration.blink)
        Task { @MainActor in
            withAnimation(animation) { progress = 1 }
        }
    }
}
