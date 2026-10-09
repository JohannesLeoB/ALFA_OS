import SwiftUI
import ALFAcolorCore
import BoardModel

/// The sections that a kind adds to the inspector. A brief that gives a kind its own fields registers its section here.
@MainActor
enum KindInspectors {
    private static let sections: [ItemKind: (BoardStore, [Item]) -> AnyView] = [
        .image: { store, items in AnyView(ImageFitSection(store: store, items: items)) },
    ]

    static func section(for kind: ItemKind, store: BoardStore, items: [Item]) -> AnyView? {
        sections[kind]?(store, items)
    }
}

/// How the images of the selection sit in their areas: fit or fill.
struct ImageFitSection: View {
    var store: BoardStore
    var items: [Item]

    var body: some View {
        let fits = items.compactMap { item -> ImageFit? in
            guard case .image(_, let crop, let fit) = item.content else { return nil }
            return ImageLayout.fit(fit, crop: crop)
        }
        let shared = SharedValue(fits)
        Section("item.kind.image") {
            Picker("inspector.fit", selection: Binding(
                get: { shared.value ?? .fit },
                set: { fit in _ = try? store.perform(imageFit: fit) }
            )) {
                Text("inspector.fit.fit").tag(ImageFit.fit)
                Text("inspector.fit.fill").tag(ImageFit.fill)
            }
            .pickerStyle(.segmented)
        }
    }
}
