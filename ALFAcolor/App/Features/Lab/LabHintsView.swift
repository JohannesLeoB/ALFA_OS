import AppTheme
import Renderers
import SwiftUI

/// The hints of the lab: one line for each thing the draft lacks, with a button for the fix where there is one.
/// At most three show, one under another.
struct LabHintsView: View {
    let model: LabModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let hints = LabHints.hints(for: model.session.draft).prefix(3)
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                row(hint)
            }
        }
        .padding(.horizontal, theme.space(.s3))
    }

    private func row(_ hint: LabHint) -> some View {
        HStack(spacing: theme.space(.s2)) {
            sentence(hint)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            if hint.fix != nil {
                Button(LocalizedStringKey("lab.hint.insertScript")) { apply(hint) }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, theme.space(.s2))
        .padding(.vertical, theme.space(.s1))
        .background(Capsule().fill(theme.color(.surface, scheme)))
    }

    @ViewBuilder
    private func sentence(_ hint: LabHint) -> some View {
        switch hint.kind {
        case .styleOnly:
            Text(LocalizedStringKey("lab.hint.styleOnly"))
        case .blockedHost(let host):
            Text(LocalizedStringKey("lab.hint.blockedHost \(host)"))
        case .library(let name):
            Text(LocalizedStringKey("lab.hint.library \(name)"))
        case .noComponent:
            Text(LocalizedStringKey("lab.hint.noComponent"))
        }
    }

    /// Takes the fixed tabs over through the model, which reloads the page. The hint goes once the draft has the line.
    private func apply(_ hint: LabHint) {
        let fixed = LabHints.apply(hint, to: model.session.draft)
        for tab in fixed.tabs where fixed.text(tab) != model.session.draft.text(tab) {
            model.edit(fixed.text(tab), in: tab)
        }
    }
}
