import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel
import ColorLab
import Tokens

/// The contrast sheet: every colour field as text on every colour field as ground, with the WCAG level of each cell.
/// A click on a cell shows a suggestion for the text colour; apply changes the text field in one undo step.
/// The matrix and the suggestion are in ColorLab; the sheet only maps the fields to rows and columns.
struct ContrastSheet: View {
    var store: BoardStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var largeText = false
    @State private var picked: Pick?

    /// The cell that is shown: the name of the text field and the name of the ground field.
    private struct Pick: Equatable {
        var text: String
        var ground: String
    }

    private var fields: [ColorFields.Field] { ColorFields.fields(in: store.document.tokenSets) }

    var body: some View {
        let fields = self.fields
        VStack(alignment: .leading, spacing: theme.space(.s4)) {
            HStack {
                Text("contrast.title")
                    .font(theme.text(.heading).font)
                Spacer()
                Toggle("contrast.large", isOn: $largeText)
                Button("contrast.close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            if fields.isEmpty {
                Text("contrast.empty")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            } else {
                Text("contrast.hint")
                    .font(theme.text(.caption).font)
                    .foregroundStyle(theme.color(.textMuted, scheme))
                ScrollView([.horizontal, .vertical]) {
                    matrix(fields)
                }
                detail(fields)
            }
        }
        .padding(theme.space(.s6))
    }

    // MARK: Matrix

    private func matrix(_ fields: [ColorFields.Field]) -> some View {
        let grid = ContrastMatrix.grid(texts: fields.map(\.color), grounds: fields.map(\.color), largeText: largeText)
        return Grid(horizontalSpacing: theme.space(.s1), verticalSpacing: theme.space(.s1)) {
            GridRow {
                Color.clear.frame(width: 96, height: 16)
                ForEach(fields) { ground in
                    Text(verbatim: ground.name)
                        .font(theme.text(.caption).font)
                        .lineLimit(1)
                        .frame(width: 72)
                }
            }
            ForEach(fields.indices, id: \.self) { row in
                GridRow {
                    Text(verbatim: fields[row].name)
                        .font(theme.text(.caption).font)
                        .lineLimit(1)
                        .frame(width: 96, alignment: .leading)
                    ForEach(fields.indices, id: \.self) { column in
                        cell(text: fields[row], ground: fields[column], result: grid[row][column])
                    }
                }
            }
        }
    }

    private func cell(text: ColorFields.Field, ground: ColorFields.Field, result: ContrastCell) -> some View {
        let isPicked = picked == Pick(text: text.name, ground: ground.name)
        return Button {
            picked = Pick(text: text.name, ground: ground.name)
        } label: {
            VStack(spacing: theme.space(.s1)) {
                Text(verbatim: "Aa")
                    .font(theme.text(.heading).font)
                Text(verbatim: String(format: "%.2f : 1", result.ratio))
                    .font(theme.text(.caption).font.monospaced())
                Text(LocalizedStringKey(levelKey(result.level)))
                    .font(theme.text(.caption).font)
            }
            .foregroundStyle(Color(text.color))
            .frame(width: 72, height: 64)
            .background(Color(ground.color))
            .overlay(Rectangle().stroke(isPicked ? theme.color(.accent, scheme) : theme.color(.border, scheme), lineWidth: isPicked ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(text.name), \(ground.name), \(String(format: "%.2f", result.ratio))"))
    }

    // MARK: Suggestion

    /// The suggestion for the picked cell, with its ratio, and the apply button. Empty when no cell is picked.
    @ViewBuilder
    private func detail(_ fields: [ColorFields.Field]) -> some View {
        if let picked,
           let text = fields.first(where: { $0.name == picked.text }),
           let ground = fields.first(where: { $0.name == picked.ground }) {
            if let suggested = ContrastSuggestion.text(text.color, on: ground.color) {
                let after = ContrastMatrix.cell(text: suggested, ground: ground.color, largeText: largeText)
                HStack(spacing: theme.space(.s2)) {
                    Rectangle()
                        .fill(Color(suggested))
                        .frame(width: 16, height: 16)
                    Text("contrast.suggestion")
                    Text(verbatim: suggested.hex)
                        .font(theme.text(.caption).font.monospaced())
                    Text(verbatim: String(format: "%.2f : 1", after.ratio))
                        .font(theme.text(.caption).font.monospaced())
                        .foregroundStyle(theme.color(.textMuted, scheme))
                    Spacer(minLength: 0)
                    Button("contrast.apply") { apply(text.name, suggested) }
                }
            } else {
                Text("contrast.enough")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
    }

    // MARK: Actions

    /// Changes the colour of the text field: one undo step. The matrix follows the document.
    private func apply(_ name: String, _ color: RGB) {
        try? store.changeTokenSets(nameKey: "undo.contrast.apply") { try ColorFields.setColor(name, to: color, in: &$0) }
    }

    private func levelKey(_ level: ContrastLevel) -> String {
        switch level {
        case .aaa: "contrast.level.aaa"
        case .aa: "contrast.level.aa"
        case .insufficient: "contrast.level.insufficient"
        }
    }
}
