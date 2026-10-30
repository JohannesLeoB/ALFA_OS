import Assistant
import Design
import SwiftUI

struct UsageBlock: View {
    @Environment(\.appearance) private var appearance
    let usage: UsageState
    @State private var asking = false

    var body: some View {
        BlockHead(key: "settings.usage.head")
        SettingsRow(label: tokensLabel) {
            if usage.totals.calls > 0 {
                SettingsValue(text: Text(verbatim: appearance.format(
                    "settings.usage.tokens.value", scaled(usage.totals.input), scaled(usage.totals.output))))
            }
        }
        SettingsRow(label: appearance.text("settings.usage.price.input")) {
            ValueField(text: Binding(get: { usage.inputPrice }, set: { usage.setPrice($0, for: .input) }),
                       labelKey: "settings.usage.price.input", prompt: appearance.text(SettingsKeys.valueEmpty))
        }
        SettingsRow(label: appearance.text("settings.usage.price.output")) {
            ValueField(text: Binding(get: { usage.outputPrice }, set: { usage.setPrice($0, for: .output) }),
                       labelKey: "settings.usage.price.output", prompt: appearance.text(SettingsKeys.valueEmpty))
        }
        if let estimate = usage.estimate {
            SettingsRow(label: appearance.text("settings.usage.estimate")) {
                SettingsValue(text: Text(verbatim: appearance.format("settings.usage.estimate.value", UsageEngine.money(estimate))))
            }
        } else {
            BlockNote(text: appearance.text("settings.usage.prices.missing"))
        }
        SettingsRow(label: appearance.text("settings.usage.counter"), line: false) {
            if asking {
                TextButton(label: appearance.text("settings.usage.reset"), kind: .signal) {
                    usage.reset()
                    asking = false
                }
                TextButton(label: appearance.text("text.common.cancel"), kind: .plain) { asking = false }
            } else {
                TextButton(label: appearance.text("settings.usage.reset.ask"), disabled: usage.totals.calls == 0) { asking = true }
            }
        }
        .task { usage.refresh() }
    }

    private var tokensLabel: Text {
        guard let since = usage.totals.since, let days = usage.days else { return appearance.text("settings.usage.tokens.none") }
        let span = appearance.format(days == 1 ? "settings.usage.day.one" : "settings.usage.day.other", String(days))
        return Text(verbatim: appearance.format("settings.usage.tokens", SettingsDates.day(since), span))
    }

    private func scaled(_ tokens: Int) -> String {
        let value = UsageEngine.scaled(tokens)
        return appearance.format(value.millions ? "settings.usage.million" : "settings.usage.thousand", value.amount)
    }
}
