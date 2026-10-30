import Design
import Hub
import Mail
import SwiftUI

struct AddEditor: View {
    @Environment(\.appearance) private var appearance
    @Bindable var flow: AccountFlow
    let offers: [Offer]
    let offer: Offer
    var added: (() -> Void)?
    @FocusState private var focused: Field.ID?

    private var fields: [Field] {
        switch offer.way {
        case .form(let fields), .key(let fields): fields
        case .signIn: []
        }
    }

    private var buttonKey: String {
        switch offer.way {
        case .key: "settings.action.connect"
        case .form: "text.settings.action.addAccount"
        case .signIn: "settings.signin"
        }
    }

    @State private var missing: [Field] = []

    private var ready: Bool { lacking.isEmpty }

    private var lacking: [Field] {
        switch offer.way {
        case .signIn: []
        case .form: fields.filter { ProviderPresets.requiredFields.contains($0.id) && !filled($0) }
        case .key: fields.filter { $0.secret && !filled($0) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if offers.count > 1 {
                SettingsRow(label: appearance.text("settings.account.provider")) {
                    ChoiceButton(label: appearance.text(offer.title)) {
                        offers.map { choice in
                            .row(MenuItem(id: choice.id, label: appearance.text(choice.title),
                                          check: choice.id == offer.id ? appearance.text(SettingsKeys.menuCheck) : nil) {
                                flow.select(choice)
                            })
                        }
                    }
                }
            }
            ForEach(fields) { field in
                SettingsRow(label: appearance.text(field.title)) { entry(field) }
            }
            if !missing.isEmpty {
                BlockNotice(kind: .failure, title: appearance.text("settings.add.check"),
                            text: Text(verbatim: appearance.format("settings.add.missing",
                                                                   missing.map { appearance.string($0.title) }.joined(separator: ", "))))
            }
            if let failure = flow.failure {
                BlockNotice(kind: .failure, title: appearance.text("settings.add.failed.title"),
                            text: Text(verbatim: failure.line(appearance)))
            }
            SettingsRow(label: Text(verbatim: ""), sub: flow.busy ? appearance.text("settings.link.connecting") : nil, line: false) {
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    TextButton(label: appearance.text(buttonKey), kind: .accent, disabled: flow.busy) { submit() }
                    TextButton(label: appearance.text("text.common.cancel"), kind: .plain) {
                        if flow.busy { flow.cancel() } else { flow.close() }
                    }
                }
            }
        }
        .onAppear { focused = fields.first { !$0.secret && choices(of: $0) == nil }?.id }
        .onChange(of: flow.values) { missing = [] }
        .onChange(of: focused) { left, _ in
            if left == ProviderPresets.addressField { flow.discover() }
        }
    }

    @ViewBuilder
    private func entry(_ field: Field) -> some View {
        if let options = choices(of: field) {
            let current = options.contains(value(field.id)) ? value(field.id) : options[0]
            ChoiceButton(label: appearance.text(ProviderPresets.choiceKey(field: field.id, option: current))) {
                options.map { option in
                    .row(MenuItem(id: option, label: appearance.text(ProviderPresets.choiceKey(field: field.id, option: option)),
                                  check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        flow.values[field.id] = option
                    })
                }
            }
        } else {
            let binding = Binding(get: { flow.values[field.id] ?? "" }, set: { flow.values[field.id] = $0 })
            Group {
                if field.secret {
                    SecureField(text: binding, prompt: nil) { appearance.text(field.title) }
                } else {
                    TextField(text: binding, prompt: nil) { appearance.text(field.title) }
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .autocorrectionDisabled()
            .focused($focused, equals: field.id)
            .onSubmit {
                if field.id == ProviderPresets.addressField, !ready { flow.discover() } else { submit() }
            }
            .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(Tokens.Spacing.step28))
        }
    }

    private func choices(of field: Field) -> [String]? {
        ProviderPresets.choices(for: field.id)
    }

    private func value(_ id: Field.ID) -> String {
        flow.values[id] ?? ""
    }

    private func filled(_ field: Field) -> Bool {
        !value(field.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        missing = lacking
        guard ready, !flow.busy else { return }
        let input: Input = if case .signIn = offer.way { .none } else { .fields(flow.values) }
        Task {
            await flow.add(offer, input: input)
            if flow.form == nil { added?() }
        }
    }
}
