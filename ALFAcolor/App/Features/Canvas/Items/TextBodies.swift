import SwiftUI
import AppTheme
import BoardModel

/// The text of a note, on the sheet of its card.
struct NoteBody: View {
    let content: NoteContent
    let detail: DetailLevel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if detail == .full {
            Group {
                if content.isEmpty {
                    Text("item.note.empty").foregroundStyle(theme.color(.textMuted, scheme))
                } else {
                    Text(verbatim: content.text).foregroundStyle(theme.color(.text, scheme))
                }
            }
            .themeText(theme.text(.body))
            .padding(theme.space(.s3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// The address of a link: the domain, the path and the note.
struct LinkBody: View {
    let content: LinkContent
    let detail: DetailLevel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if detail == .full {
            VStack(alignment: .leading, spacing: theme.space(.s1)) {
                Text(verbatim: content.domain)
                    .themeText(theme.text(.body))
                    .foregroundStyle(theme.color(.text, scheme))
                    .lineLimit(1)
                if !content.path.isEmpty {
                    Text(verbatim: content.path)
                        .themeText(theme.text(.caption))
                        .foregroundStyle(theme.color(.textMuted, scheme))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if let note = content.note {
                    Text(verbatim: note)
                        .themeText(theme.text(.body))
                        .foregroundStyle(theme.color(.text, scheme))
                }
            }
            .padding(theme.space(.s3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// Free text on the canvas, in one of the text styles of the theme.
struct TextBody: View {
    let content: TextContent
    let detail: DetailLevel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if detail == .full {
            Group {
                if content.text.isEmpty {
                    Text("item.text.empty").foregroundStyle(theme.color(.textMuted, scheme))
                } else {
                    Text(verbatim: content.text).foregroundStyle(theme.color(.text, scheme))
                }
            }
            .themeText(theme.text(content.role.token))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
    }
}

extension TextRole {
    /// The text style of the theme for this role.
    var token: TextToken {
        switch self {
        case .heading: .heading
        case .body: .body
        case .caption: .caption
        }
    }
}

/// The name of the kind, for cards that another part draws.
struct KindBody: View {
    let kindKey: String
    let detail: DetailLevel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if detail == .full {
            Text(LocalizedStringKey(kindKey))
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
