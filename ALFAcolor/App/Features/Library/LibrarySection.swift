import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel
import Library

/// The "Sammlung" part of the sidebar: the search field, the scopes (all items, images, links), the folders
/// and the results. Results are drag sources; a drop on the canvas puts a copy in the active room.
/// Folder edits run through the board, so each one is an undo step.
struct LibrarySection: View {
    var store: BoardStore

    /// What the results show.
    enum Scope: Hashable {
        case all, images, links
        case folder(String)
    }

    /// One result, as the list shows it.
    struct Row {
        let title: String
        let kind: ItemKind
    }

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var index = LibraryIndex(board: Board(title: ""))
    @State private var rows: [ItemRef: Row] = [:]
    @State private var scope: Scope = .all
    @State private var query = ""
    /// Only items that may be used freely: own work or a free licence.
    @State private var freeOnly = false
    @State private var renaming: Folder?
    @State private var renameText = ""

    var body: some View {
        Group {
            Section {
                TextField("library.search", text: $query)
                    .textFieldStyle(.roundedBorder)
                scopeRow(.all, title: "sidebar.allItems", symbol: "square.grid.2x2")
                scopeRow(.images, title: "sidebar.images", symbol: "photo")
                scopeRow(.links, title: "sidebar.links", symbol: "link")
                Toggle("library.freeOnly", isOn: $freeOnly)
                    .lineLimit(1)
            } header: {
                Text("sidebar.collection")
            }
            Section {
                ForEach(store.board.folders) { folder in
                    folderRow(folder)
                }
                Button(action: addFixedFolder) {
                    Label("library.folder.newFixed", systemImage: "folder.badge.plus")
                        .lineLimit(1)
                }
                .buttonStyle(.borderless)
                Button(action: addSmartFolder) {
                    Label("library.folder.newSmart", systemImage: "line.3.horizontal.decrease.circle")
                        .lineLimit(1)
                }
                .buttonStyle(.borderless)
            } header: {
                Text("library.folders")
            }
            Section {
                ForEach(results, id: \.self) { ref in
                    resultRow(ref)
                }
                if results.isEmpty {
                    Text("library.empty")
                        .foregroundStyle(theme.color(.textMuted, scheme))
                }
            } header: {
                Text("library.results")
            }
        }
        .onChange(of: store.revision, initial: true) { refresh() }
        .alert("library.folder.rename", isPresented: renameBinding) {
            TextField("library.folder.name", text: $renameText)
            Button("library.folder.rename") { commitRename() }
            Button("library.cancel", role: .cancel) { renaming = nil }
        }
    }

    // MARK: Reading

    private func refresh() {
        index = LibraryIndex(board: store.board)
        var table: [ItemRef: Row] = [:]
        for space in store.board.spaces {
            for item in space.items {
                table[ItemRef(spaceID: space.id, itemID: item.id)] = Row(title: item.title, kind: ItemKind(item.content))
            }
        }
        rows = table
    }

    /// The items in the scope, narrowed by the search field, in board order.
    private var results: [ItemRef] {
        refs(in: scope, query: query)
    }

    private func refs(in scope: Scope, query: String) -> [ItemRef] {
        let free: Bool? = freeOnly ? true : nil
        switch scope {
        case .all:
            return index.search(LibraryFilter(text: query, freeLicenseOnly: free))
        case .images:
            return index.search(LibraryFilter(text: query, kinds: [.image], freeLicenseOnly: free))
        case .links:
            return index.search(LibraryFilter(text: query, kinds: [.link], freeLicenseOnly: free))
        case .folder(let id):
            guard let folder = store.board.folders.first(where: { $0.id == id }) else { return [] }
            let matching = Set(index.search(LibraryFilter(text: query, freeLicenseOnly: free)))
            return index.items(in: folder).filter { matching.contains($0) }
        }
    }

    private func count(_ scope: Scope) -> Int {
        refs(in: scope, query: "").count
    }

    private var fixedFolders: [Folder] {
        store.board.folders.filter { if case .fixed = $0.rule { true } else { false } }
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    // MARK: Rows

    private func scopeRow(_ value: Scope, title: LocalizedStringKey, symbol: String) -> some View {
        Button { scope = value } label: {
            HStack {
                Label(title, systemImage: symbol)
                    .lineLimit(1)
                Spacer()
                Text(count(value).formatted())
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .buttonStyle(.plain)
        .fontWeight(scope == value ? .semibold : .regular)
    }

    private func folderRow(_ folder: Folder) -> some View {
        let value = Scope.folder(folder.id)
        let isSmart: Bool = { if case .smart = folder.rule { true } else { false } }()
        return Button { scope = value } label: {
            HStack {
                Label {
                    Text(folder.name).lineLimit(1).truncationMode(.tail)
                } icon: {
                    Image(systemName: isSmart ? "line.3.horizontal.decrease.circle" : "folder")
                }
                Spacer()
                Text(count(value).formatted())
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .buttonStyle(.plain)
        .fontWeight(scope == value ? .semibold : .regular)
        .contextMenu {
            Button("library.folder.rename") {
                renameText = folder.name
                renaming = folder
            }
            Button("library.folder.delete", role: .destructive) { deleteFolder(folder) }
        }
    }

    private func resultRow(_ ref: ItemRef) -> some View {
        let row = rows[ref]
        return Label {
            Text(row?.title ?? "").lineLimit(1).truncationMode(.tail)
        } icon: {
            Image(systemName: Self.symbol(for: row?.kind))
        }
        .draggable(LibraryDrag(ref: ref))
        .contextMenu {
            Menu("library.folder.addItem") {
                ForEach(fixedFolders) { folder in
                    Button(folder.name) { addItem(ref, to: folder) }
                }
            }
            if case .folder(let id) = scope, fixedFolders.contains(where: { $0.id == id }) {
                Button("library.folder.removeItem") { removeItem(ref, from: id) }
            }
        }
    }

    static func symbol(for kind: ItemKind?) -> String {
        switch kind {
        case .image: "photo"
        case .note: "note.text"
        case .text: "textformat"
        case .shape: "square.on.circle"
        case .swatch: "paintpalette"
        case .link: "link"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .frame: "iphone"
        case .group: "rectangle.dashed"
        case nil: "questionmark.square"
        }
    }

    // MARK: Folder edits (each one undo step)

    private func addFixedFolder() {
        addFolder(FolderRule.fixed([]), nameKey: "library.folder.defaultFixed")
    }

    /// Saves the current search and scope as a smart folder. From a folder scope only the search text is saved.
    private func addSmartFolder() {
        let free: Bool? = freeOnly ? true : nil
        let filter: LibraryFilter
        switch scope {
        case .all: filter = LibraryFilter(text: query, freeLicenseOnly: free)
        case .images: filter = LibraryFilter(text: query, kinds: [.image], freeLicenseOnly: free)
        case .links: filter = LibraryFilter(text: query, kinds: [.link], freeLicenseOnly: free)
        case .folder: filter = LibraryFilter(text: query, freeLicenseOnly: free)
        }
        addFolder(FolderRule.smart(filter), nameKey: "library.folder.defaultSmart")
    }

    private func addFolder(_ rule: FolderRule, nameKey: String) {
        let folder = Folder(id: UUID().uuidString, name: String(localized: String.LocalizationValue(nameKey)), rule: rule)
        _ = try? store.changeBoard(nameKey: "undo.folder.add") { board in
            try FolderEdit.add(folder, to: &board.folders)
        }
        scope = .folder(folder.id)
    }

    private func commitRename() {
        guard let folder = renaming else { return }
        renaming = nil
        let name = renameText
        _ = try? store.changeBoard(nameKey: "undo.folder.rename") { board in
            try FolderEdit.rename(folder.id, to: name, in: &board.folders)
        }
    }

    private func deleteFolder(_ folder: Folder) {
        if scope == .folder(folder.id) { scope = .all }
        _ = try? store.changeBoard(nameKey: "undo.folder.delete") { board in
            try FolderEdit.delete(folder.id, from: &board.folders)
        }
    }

    private func addItem(_ ref: ItemRef, to folder: Folder) {
        _ = try? store.changeBoard(nameKey: "undo.folder.items.add") { board in
            let snapshot = board
            try FolderEdit.addItems([ref], to: folder.id, in: &board.folders, board: snapshot)
        }
    }

    private func removeItem(_ ref: ItemRef, from folderID: String) {
        _ = try? store.changeBoard(nameKey: "undo.folder.items.remove") { board in
            try FolderEdit.removeItems([ref], from: folderID, in: &board.folders)
        }
    }
}
