import ShellCore
import SwiftUI

struct BlobMenuView: View {
    let theme: Theme
    @Bindable var model: ShellModel
    let available: CGFloat
    @FocusState private var searchFocused: Bool

    private var background: Color { theme.design(\.inverse) }
    private var foreground: Color { theme.design(\.onInverse) }
    private var muted: Color { theme.design(\.handle) }
    private var line: Color { theme.design(\.inverseLine) }
    private var hot: Color { theme.design(\.inverseHot) }

    var body: some View {
        let radius = CGFloat(Design.Radius.contextMenu)
        let open = model.menuOpen
        let upward = !model.blob.menuOrigin(window: model.window, geometry: theme.geometry).opensDownward
        VStack(spacing: 0) {
            search
            ScrollView { list }
                .scrollIndicators(.never)
                .frame(height: min(listHeight, max(available - chrome, 0)))
            footer
        }
        .padding(theme.length(.componentMenuPadding))
        .frame(width: theme.length(.componentMenuWidth))
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(RevealShape(progress: open ? 1 : 0, fromTop: !upward, radius: radius))
        .themeShadow(theme, .shadowFloating, shape: RoundedRectangle(cornerRadius: radius))
        .opacity(open ? 1 : 0)
        .allowsHitTesting(open)
        .animation(theme.animation(.motionDurationStack), value: open)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text("menu.label"))
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(rows, id: \.group.id) { row in
                groupHeader(row.group)
                if model.isGroupOpen(row.group) {
                    ForEach(row.apps, id: \.id) { entry in appRow(entry) }
                }
            }
        }
    }

    private var listHeight: CGFloat {
        let count = rows.reduce(0) { $0 + 1 + (model.isGroupOpen($1.group) ? $1.apps.count : 0) }
        return CGFloat(count) * theme.length(.componentMenuRowHeight) + CGFloat(rows.count) * theme.length(.spaceXxs)
    }

    private var chrome: CGFloat {
        theme.length(.componentMenuPadding) * 2
            + theme.length(.componentFieldCompactHeight) + theme.length(.spaceXs) + theme.length(.spaceXxs)
            + theme.length(.strokeHairline) + theme.length(.spaceXs) * 2 + theme.length(.componentMenuRowHeight)
    }

    private var rows: [(group: AppGroup, apps: [AppEntry])] {
        model.directory.rows(matching: model.query) { theme.string($0) }
    }

    private var search: some View {
        ZStack(alignment: .leading) {
            if model.query.isEmpty {
                theme.text("menu.search")
                    .font(theme.font(.callout))
                    .foregroundStyle(muted)
                    .allowsHitTesting(false)
            }
            TextField("", text: $model.query)
                .textFieldStyle(.plain)
                .font(theme.font(.callout))
                .focused($searchFocused)
                .accessibilityLabel(theme.text("menu.search.label"))
        }
        .padding(.horizontal, theme.measure(.menuFieldPadding))
        .frame(height: theme.length(.componentFieldCompactHeight))
        .overlay(Capsule().strokeBorder(line, lineWidth: theme.length(.strokeHairline)))
        .padding(.horizontal, theme.length(.spaceXxs))
        .padding(.top, theme.length(.spaceXxs))
        .padding(.bottom, theme.length(.spaceXs))
    }

    private func groupHeader(_ group: AppGroup) -> some View {
        Button { model.toggleGroup(group) } label: {
            HStack {
                theme.text(group.titleKey).textCase(.uppercase)
                Spacer(minLength: 0)
                Image(systemName: model.isGroupOpen(group) ? "minus" : "plus")
            }
            .font(theme.font(.caption))
            .tracking(theme.tracking(.caption))
            .foregroundStyle(muted)
            .padding(.horizontal, theme.measure(.menuGroupPadding))
            .frame(height: theme.length(.componentMenuRowHeight))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, theme.length(.spaceXxs))
    }

    private func appRow(_ entry: AppEntry) -> some View {
        let current = entry.id == model.currentID
        return MenuRow(theme: theme, current: current, hover: hot, foreground: foreground, background: background) {
            model.select(entry.id)
        } content: {
            HStack(spacing: theme.length(.spaceS)) {
                theme.text(entry.titleKey)
                Spacer(minLength: 0)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(line).frame(height: theme.length(.strokeHairline))
                .padding(.vertical, theme.length(.spaceXs))
            MenuRow(theme: theme, current: false, hover: hot, foreground: foreground, background: background) {
                model.toggleAssistant()
            } content: {
                HStack(spacing: theme.length(.spaceS)) {
                    theme.text("menu.assistant")
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct MenuRow<Content: View>: View {
    let theme: Theme
    let current: Bool
    let hover: Color
    let foreground: Color
    let background: Color
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content()
                .font(theme.font(.callout))
                .foregroundStyle(current ? background : foreground)
                .padding(.leading, theme.measure(.menuRowPaddingStart))
                .padding(.trailing, theme.measure(.menuRowPaddingEnd))
                .frame(height: theme.length(.componentMenuRowHeight))
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
                        .fill(current ? foreground : (hovering ? hover : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
