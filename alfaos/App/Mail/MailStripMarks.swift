import Mail
import ShellCore
import SwiftUI

struct MailStripMarks: View {
    let model: MailModel
    let lane: Lane
    let height: Double

    var body: some View {
        VStack(spacing: CGFloat(Design.Spacing.step8)) {
            ForEach(model.stripMarks(lane, height: height)) { mark in
                StripMarkButton(glyph: mark.glyph, text: mark.text, help: mark.help.key.map { word($0) } ?? Text(verbatim: mark.help.text),
                                selected: mark.selected, dot: mark.dot) { Task { await model.run(mark.run) } }
            }
        }
        .padding(.vertical, CGFloat(Design.Spacing.step8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension MailStripMark {
    var glyph: Icon? {
        if case .glyph(let icon) = face { icon } else { nil }
    }

    var text: String {
        if case .text(let value) = face { value } else { "" }
    }
}

struct StripMarkButton: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let glyph: Icon?
    let text: String
    let help: Text
    let selected: Bool
    let dot: Bool
    let action: () -> Void

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        Button(action: action) {
            Group {
                if let glyph {
                    Glyph(glyph)
                } else {
                    Text(verbatim: text).lineLimit(1)
                }
            }
            .designText(selected ? \.lane : \.inkSecondary, size: Design.TextSize.small, weight: .medium)
            .frame(width: side, height: side)
            .background(Circle().fill(selected ? design.color(\.ink) : Color.clear))
            .overlay(Circle().strokeBorder(selected ? Color.clear : design.color(\.lineStrong), lineWidth: hairline))
            .overlay(alignment: .topTrailing) {
                if dot {
                    Circle().fill(design.color(\.ink))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .overlay(Circle().strokeBorder(design.color(\.lane), lineWidth: CGFloat(Design.Size.markSeparatorRing)))
                        .offset(x: hairline, y: -hairline)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
