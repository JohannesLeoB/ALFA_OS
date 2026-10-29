import AppKit
import Design
import Mail
import Shell
import SwiftUI

struct FormatRow: View {
    @Environment(\.appearance) private var appearance
    let box: TextBox

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
            item("mail.format.bold", .bold) { box.toggle(.boldFontMask) }
            item("mail.format.italic", .italic) { box.toggle(.italicFontMask) }
            item("mail.format.underline", .underline) { box.toggleUnderline() }
            item("mail.format.list", .list) { box.toggleList(.bullet) }
            item("mail.format.numbered", .numbered) { box.toggleList(.number) }
            item("mail.format.link", .link) { askLink() }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .overlay(alignment: .top) { Hairline() }
    }

    private func item(_ key: String, _ glyph: Icon, _ action: @escaping () -> Void) -> some View {
        SymbolButton(help: appearance.string(key), glyph: glyph, side: Tokens.Spacing.step28, tone: \.inkSecondary, hover: .fill, action: action)
    }

    private func askLink() {
        let alert = NSAlert()
        alert.messageText = appearance.string("mail.format.link")
        let field = NSTextField(string: "")
        field.placeholderString = appearance.string("mail.format.linkPlaceholder")
        field.frame.size.width = CGFloat(SheetValues.linkFieldWidth)
        alert.accessoryView = field
        alert.addButton(withTitle: appearance.string("mail.format.linkApply"))
        alert.addButton(withTitle: appearance.string("mail.format.linkCancel"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        box.link(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
