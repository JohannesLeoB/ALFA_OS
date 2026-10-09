import SwiftUI
import ALFAcolorCore
import BoardModel

/// The guides of the selected frame: one row each, with its position and a button to remove it, and a button
/// to remove all of them. Shown for one frame only; with several frames the guides differ, so nothing is listed.
struct GuideSection: View {
    var store: BoardStore
    var items: [Item]

    var body: some View {
        if items.count == 1, let frame = items.first, case .frame = frame.content {
            let guides = FrameGuides.guides(of: frame)
            Text("inspector.frame.guides")
                .font(.headline)
            if guides.isEmpty {
                Text("inspector.frame.guides.none")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(guides.enumerated()), id: \.offset) { index, guide in
                GuideRow(store: store, frame: frame.id, index: index, guide: guide)
            }
            if !guides.isEmpty {
                Button("inspector.frame.guides.removeAll", role: .destructive) {
                    _ = try? store.perform(guidesRemoveAllFrom: frame.id)
                }
            }
        }
    }
}
