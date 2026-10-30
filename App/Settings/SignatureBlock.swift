import Design
import Hub
import SwiftUI

struct SignatureBlock: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inlet: Inlet

    private var who: String { inlet.account.isEmpty ? appearance.string(inlet.title) : inlet.account }

    var body: some View {
        Text(verbatim: appearance.format("settings.signature.head", who))
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step36), alignment: .bottomLeading)
        if let signature = state.signature(inlet.id) {
            editor(signature)
            SettingsRow(label: appearance.text("settings.signature.new"), sub: appearance.text("settings.signature.new.sub")) {
                ToggleSwitch(isOn: Binding(get: { signature.onNew }, set: { state.setSignatureOnNew($0, for: inlet.id) }),
                             labelKey: "settings.signature.new")
            }
            SettingsRow(label: appearance.text("settings.signature.above")) {
                ToggleSwitch(isOn: Binding(get: { signature.aboveQuote }, set: { state.setSignatureAboveQuote($0, for: inlet.id) }),
                             labelKey: "settings.signature.above")
            }
            SettingsRow(label: Text(verbatim: ""), line: false) {
                TextButton(label: appearance.text("settings.signature.remove"), kind: .plain) { state.removeSignature(for: inlet.id) }
            }
        } else {
            BlockNote(text: appearance.text("settings.signature.empty"))
            SettingsRow(label: Text(verbatim: ""), line: false) {
                TextButton(label: appearance.text("settings.signature.create"), kind: .accent) { state.setSignature("", for: inlet.id) }
            }
        }
    }

    private func editor(_ signature: MailboxSignature) -> some View {
        TextEditor(text: Binding(get: { signature.text }, set: { state.setSignature($0, for: inlet.id) }))
            .scrollContentBackground(.hidden)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .accessibilityLabel(Text(verbatim: appearance.format("settings.signature.area", who)))
            .padding(.vertical, CGFloat(Tokens.Spacing.step8))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            .frame(minHeight: CGFloat(Tokens.Size.signatureEditorMinHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice)).fill(appearance.color(\.well)))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.top, CGFloat(Tokens.Spacing.step4))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
    }
}
