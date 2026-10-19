import AppKit
import Mail
import ShellCore
import SwiftUI

struct GlyphShape: Shape {
    let glyph: Icon

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / CGFloat(SheetValues.iconBox)
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(x) * scale, y: rect.minY + CGFloat(y) * scale)
        }
        var path = Path()
        for segment in glyph.path.segments {
            switch segment {
            case .move(let x, let y): path.move(to: point(x, y))
            case .line(let x, let y): path.addLine(to: point(x, y))
            case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
                path.addCurve(to: point(x, y), control1: point(c1x, c1y), control2: point(c2x, c2y))
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

struct Glyph: View {
    let glyph: Icon
    var size = SheetValues.iconSize
    var stroke = SheetValues.iconStroke

    init(_ glyph: Icon, size: Double = SheetValues.iconSize, stroke: Double = SheetValues.iconStroke) {
        self.glyph = glyph
        self.size = size
        self.stroke = stroke
    }

    var body: some View {
        GlyphShape(glyph: glyph)
            .stroke(style: StrokeStyle(lineWidth: CGFloat(stroke * size / SheetValues.iconBox), lineCap: .round, lineJoin: .round))
            .frame(width: CGFloat(size), height: CGFloat(size))
    }
}

extension Glyph {
    static func small(_ glyph: Icon) -> Glyph {
        Glyph(glyph, size: SheetValues.smallIcon, stroke: SheetValues.smallIconStroke)
    }

    static func tiny(_ glyph: Icon) -> Glyph {
        Glyph(glyph, size: SheetValues.tinyIcon, stroke: SheetValues.tinyIconStroke)
    }
}

struct MailLaneLink: Sendable {
    var openLanes = 3
    var fold: @MainActor @Sendable (Lane) -> Void = { _ in }
    var maximized: Lane?
    var toggleMaximize: @MainActor @Sendable (Lane) -> Void = { _ in }
    var openSettings: @MainActor @Sendable () -> Void = {}
}

extension MailLaneLink {
    @MainActor
    init(shell: ShellModel) {
        let open = shell.widths.all.filter { $0 > shell.geometry.laneFolded }.count
        self.init(openLanes: open, fold: { shell.toggleFold($0) }, maximized: shell.laneState(shell.currentID).maximized,
                  toggleMaximize: { shell.toggleMaximize($0) }, openSettings: { shell.select("settings") })
    }
}

extension MailAction {
    var shortcut: KeyboardShortcut? {
        switch self {
        case .reply: KeyboardShortcut("r", modifiers: .command)
        case .replyAll: KeyboardShortcut("r", modifiers: [.command, .shift])
        case .forward: KeyboardShortcut("f", modifiers: [.command, .shift])
        case .saveDraft: KeyboardShortcut("s", modifiers: .command)
        case .print: KeyboardShortcut("p", modifiers: .command)
        default: nil
        }
    }
}

private struct MailLaneLinkKey: EnvironmentKey {
    static let defaultValue: MailLaneLink? = nil
}

extension EnvironmentValues {
    var mailLaneLink: MailLaneLink? {
        get { self[MailLaneLinkKey.self] }
        set { self[MailLaneLinkKey.self] = newValue }
    }
}

func words(_ key: String, _ args: CVarArg...) -> String {
    let format = String(localized: String.LocalizationValue(key))
    return args.isEmpty ? format : String(format: format, arguments: args)
}

func line(_ key: String, _ args: CVarArg...) -> Text {
    Text(verbatim: args.isEmpty ? words(key) : String(format: words(key), arguments: args))
}

extension View {
    func scrolledSignal(_ scrolled: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 0 } action: { _, now in scrolled.wrappedValue = now }
    }
}

struct LaneHead<Content: View>: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    var scrolled = false
    var leading = Design.Size.headPadLeftList
    var gap = Design.Size.headGapList
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(gap)) { content }
            .padding(.leading, CGFloat(leading))
            .padding(.trailing, CGFloat(Design.Size.headPadRight))
            .frame(height: CGFloat(Design.Size.headerHeight))
            .frame(maxWidth: .infinity)
            .background(laneFill)
            .overlay(alignment: .bottom) {
                Rectangle().fill(scrolled ? design.color(\.line) : Color.clear).frame(height: hairline)
            }
            .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: scrolled)
    }
}

struct HeaderTitle: View {
    let text: Text

    var body: some View {
        text
            .designText(\.ink, size: Design.TextSize.body, weight: .medium)
            .lineLimit(1)
            .fixedSize()
    }
}

struct SmallText: View {
    let text: Text
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary

    var body: some View {
        text
            .designText(tone, size: Design.TextSize.small)
            .lineLimit(1)
    }
}

struct Hairline: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    var tone: KeyPath<DesignColors, RGB> = \.line

    var body: some View {
        Rectangle().fill(design.color(tone)).frame(height: hairline)
    }
}
