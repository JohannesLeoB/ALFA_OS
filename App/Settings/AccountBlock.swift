import Core
import Hub
import SwiftUI

struct AccountBlock: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let info: IntegrationInfo
    let reading: IntegrationReading
    @Binding var started: Bool

    private var flow: AccountFlow { context.flow }

    var body: some View {
        BlockHead(key: "settings.accounts.head")
        if let offer = flow.form, info.providers.contains(offer.provider) {
            AddEditor(flow: flow, offers: reading.offers, offer: offer, added: { context.state.notify("settings.toast.accountAdded") })
        } else if reading.inlets.isEmpty {
            BlockNotice(kind: .warning, title: appearance.text("settings.accounts.none.title")) {
                addAccount(kind: .accent)
            }
        } else {
            ForEach(reading.inlets) { inlet in
                SettingsRow(label: inlet.account.isEmpty ? appearance.text(inlet.title) : Text(verbatim: inlet.account),
                            sub: inlet.account.isEmpty ? nil : appearance.text(inlet.title),
                            line: !Self.hasMailbox(inlet)) {
                    ConnectionStatus(state: LinkState(inlet.state).connection, label: appearance.text(LinkState(inlet.state).key))
                    TextButton(label: appearance.text("text.settings.action.check"), kind: .plain, disabled: flow.busy) {
                        started = true
                        Task { await flow.probe(inlet.id) }
                    }
                }
                if Self.hasMailbox(inlet) {
                    MailboxNameRow(state: context.state, inlet: inlet)
                    MailboxDisplayRow(state: context.state, inlet: inlet)
                    MailboxRangeRow(state: context.state, inbox: context.inbox, inlet: inlet)
                    MailboxServerCopyRow(state: context.state, inbox: context.inbox, inlet: inlet)
                    SignatureBlock(state: context.state, inlet: inlet)
                }
                SettingsRow(label: appearance.text("settings.account.remove")) {
                    ConfirmPill(
                        label: appearance.text("text.settings.action.remove"),
                        question: Text(verbatim: [appearance.string("settings.account.remove.ask"),
                                                  Self.waiting([inlet.id], context: context, appearance: appearance)]
                            .compactMap { $0 }.joined(separator: " ")),
                        yes: appearance.text("text.settings.action.remove"),
                        no: appearance.text("confirm.no"),
                        holdHint: appearance.text("settings.hold.remove"),
                        showsProgress: false,
                        onYes: {
                            started = true
                            Task { await flow.remove([inlet.id]) }
                        }
                    )
                    .rowPill()
                }
            }
            SettingsRow(label: Text(verbatim: ""), line: false) {
                addAccount(kind: .neutral)
            }
        }
    }

    static func hasMailbox(_ inlet: Inlet) -> Bool {
        inlet.capabilities.contains(.mail)
    }

    static func waiting(_ inlets: [Inlet.ID], context: SettingsContext, appearance: Appearance) -> String? {
        let count = inlets.reduce(0) { $0 + context.inbox.unsent($1) }
        let local = inlets.contains(where: context.inbox.inboxOnly) ? appearance.string("settings.disconnect.local") : nil
        let unsent = count == 0 ? nil : count == 1 ? appearance.string("settings.disconnect.waiting.one")
            : appearance.format("settings.disconnect.waiting.other", Format.number(count))
        let text = [local, unsent].compactMap { $0 }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    private func addAccount(kind: TextButtonKind) -> some View {
        TextButton(label: appearance.text("text.settings.action.addAccount"), kind: kind, disabled: flow.busy || reading.offers.isEmpty) {
            started = true
            flow.open(reading.offers)
        }
    }
}
