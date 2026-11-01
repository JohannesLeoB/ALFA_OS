import Design
import Shell
import SwiftUI

enum NoticeKind {
    case failure
    case success
    case warning
}

struct Notice<Glyph: View, Actions: View>: View {
    @Environment(\.appearance) private var appearance
    let kind: NoticeKind
    let title: Text
    let text: Text?
    var onSheet = false
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let actions: Actions

    private var symbolTone: KeyPath<Colors, ColorValue> {
        if onSheet { return \.sheetInkSecondary }
        switch kind {
        case .failure: return \.signal
        case .success: return \.ink
        case .warning: return \.inkSecondary
        }
    }

    var body: some View {
        let symbol = CGFloat(Tokens.Size.symbolSize)
        HStack(alignment: .top, spacing: CGFloat(Tokens.Spacing.step20)) {
            glyph
                .foregroundStyle(appearance.color(symbolTone))
                .frame(width: symbol, height: symbol)
                .ring(Circle(), appearance.color(onSheet ? \.sheetLineStrong : symbolTone))
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                title
                    .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                    .foregroundStyle(appearance.color(onSheet ? \.sheetInk : \.ink))
                    .lineHeight(Tokens.LineHeight.notice, size: Tokens.TextSize.body)
                if let text {
                    text
                        .font(.face(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(onSheet ? \.sheetInkTertiary : \.inkTertiary))
                        .lineHeight(Tokens.LineHeight.notice, size: Tokens.TextSize.body)
                }
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) { actions }
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, CGFloat(Tokens.Spacing.step4))
        }
        .padding(CGFloat(Tokens.Spacing.step8))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice))
                .fill(appearance.color(onSheet ? \.sheetWell : \.well))
        )
    }
}

struct ToastView: View {
    @Environment(\.appearance) private var appearance
    let message: Text
    var undoLabel: Text?
    var onUndo: (() -> Void)?
    var failed = false
    var lasts: Double?
    let onDismiss: () -> Void

    private var stay: Double {
        if failed { return Tokens.Duration.toastFail }
        if let lasts, onUndo != nil { return lasts }
        return onUndo == nil ? Tokens.Duration.toast : Tokens.Duration.toastUndo
    }

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            if failed {
                Glyph(.alert)
                    .padding(.leading, -CGFloat(Tokens.Spacing.step4))
            }
            message.lineLimit(1).help(message)
            if let undoLabel, let onUndo {
                Button(action: onUndo) {
                    undoLabel
                        .lineLimit(1)
                        .fixedSize()
                        .typeStyle(Tokens.TextStyle.control)
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .frame(height: CGFloat(Tokens.Spacing.step20))
                        .ring(Pill(), appearance.color(\.onInverse))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -CGFloat(Tokens.Spacing.step8))
            }
        }
        .font(.face(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(\.onInverse))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .background(Capsule().fill(appearance.color(\.inverse)))
        .shadowLayers(Capsule())
        .task(id: stay) {
            try? await Task.sleep(for: .seconds(stay))
            if !Task.isCancelled { onDismiss() }
        }
    }
}

struct ContentPlaceholder<Glyph: View, Action: View>: View {
    enum Kind {
        case loading
        case permissionRequired
        case failed
        case noResults
        case empty
    }

    @Environment(\.appearance) private var appearance
    let kind: Kind
    var title: Text?
    let text: Text
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let action: Action

    var body: some View {
        let symbol = CGFloat(Tokens.Size.symbolSize)
        VStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            ZStack {
                if kind == .loading { Spinner() } else { glyph }
            }
            .foregroundStyle(appearance.color(\.inkTertiary))
            .frame(width: symbol, height: symbol)
            .ring(Circle(), appearance.color(\.lineStrong))
            if let title {
                title
                    .typeStyle(Tokens.TextStyle.bodyEmphasis)
                    .foregroundStyle(appearance.color(\.ink))
                    .lineHeight(Tokens.TextStyle.bodyEmphasis.lineHeight, size: Tokens.TextStyle.bodyEmphasis.size)
                    .frame(maxWidth: CGFloat(Tokens.Size.cardStateTextMaxWidth))
            }
            text
                .typeStyle(Tokens.TextStyle.body)
                .foregroundStyle(appearance.color(\.inkTertiary))
                .lineHeight(Tokens.TextStyle.body.lineHeight, size: Tokens.TextStyle.body.size)
                .frame(maxWidth: CGFloat(Tokens.Size.cardStateTextMaxWidth))
            action
        }
        .multilineTextAlignment(.center)
        .padding(CGFloat(Tokens.Spacing.step24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentPlaceholder where Glyph == EmptyView, Action == EmptyView {
    init(loading text: Text) {
        self.init(kind: .loading, text: text, glyph: { EmptyView() }, action: { EmptyView() })
    }
}
