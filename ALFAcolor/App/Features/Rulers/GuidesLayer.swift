import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// A guide of a frame on the board: the frame and the index of the guide in it.
struct GuideRef: Hashable {
    var frame: ItemID
    var index: Int
}

/// The guides of the frames as thin coral lines across each frame. A double click on a guide opens its
/// number field. The layer sits in the overlay of the rulers, so `lead` maps canvas points to the overlay.
struct GuidesLayer: View {
    var canvas: CanvasController
    var shell: ShellState
    /// Canvas position of the top left corner of the overlay, in canvas points.
    var lead: CGPoint

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var editing: GuideRef?

    /// A guide on the overlay: its line and the strip that takes the double click.
    private struct Placed: Identifiable {
        var ref: GuideRef
        var guide: Guide
        var from: CGPoint
        var to: CGPoint
        var strip: CGRect
        var id: GuideRef { ref }
    }

    var body: some View {
        let coral = theme.color(.coral, scheme)
        let placed = shell.guidesVisible ? placedGuides() : []
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for line in placed {
                    var path = Path()
                    path.move(to: line.from)
                    path.addLine(to: line.to)
                    context.stroke(path, with: .color(coral), lineWidth: SelectionStyle.lineWidth)
                }
            }
            .allowsHitTesting(false)
            if !shell.guidesLocked {
                ForEach(placed) { line in
                    Color.clear
                        .frame(width: line.strip.width, height: line.strip.height)
                        .contentShape(Rectangle())
                        .position(x: line.strip.midX, y: line.strip.midY)
                        .onTapGesture(count: 2) { editing = line.ref }
                        .popover(isPresented: Binding(get: { editing == line.ref }, set: { if !$0 { editing = nil } })) {
                            GuideRow(store: canvas.store, frame: line.ref.frame, index: line.ref.index, guide: line.guide)
                                .padding()
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The guides of the visible frames, placed in the overlay. The strip is as wide as the frame and as high as
    /// the hit reach, which is a fraction of the spacing token.
    private func placedGuides() -> [Placed] {
        let viewport = canvas.viewport
        let reach = theme.space(.s2)
        var result: [Placed] = []
        for item in canvas.store.activeSpace?.visibleItems ?? [] {
            guard case .frame = item.content else { continue }
            let left = (item.rect.x - viewport.offsetX) * viewport.zoom - lead.x
            let right = (item.rect.maxX - viewport.offsetX) * viewport.zoom - lead.x
            let top = (item.rect.y - viewport.offsetY) * viewport.zoom - lead.y
            let bottom = (item.rect.maxY - viewport.offsetY) * viewport.zoom - lead.y
            for (index, guide) in FrameGuides.guides(of: item).enumerated() where FrameGuides.isValid(guide, in: item.rect) {
                let ref = GuideRef(frame: item.id, index: index)
                switch guide.axis {
                case .horizontal:
                    let y = (item.rect.y + guide.position - viewport.offsetY) * viewport.zoom - lead.y
                    result.append(Placed(ref: ref, guide: guide, from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y),
                                         strip: CGRect(x: left, y: y - reach / 2, width: right - left, height: reach)))
                case .vertical:
                    let x = (item.rect.x + guide.position - viewport.offsetX) * viewport.zoom - lead.x
                    result.append(Placed(ref: ref, guide: guide, from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: bottom),
                                         strip: CGRect(x: x - reach / 2, y: top, width: reach, height: bottom - top)))
                }
            }
        }
        return result
    }
}

/// One guide in the inspector or in the popover of a guide: its direction, its position in points and a button to remove it.
struct GuideRow: View {
    var store: BoardStore
    var frame: ItemID
    var index: Int
    var guide: Guide

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            HStack {
                TextField("", text: $draft)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .onSubmit(send)
                Button(role: .destructive) {
                    _ = try? store.perform(guideRemove: index, frame: frame)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("guide.remove")
            }
        } label: {
            Text(LocalizedStringKey(guide.axis == .horizontal ? "guide.horizontal" : "guide.vertical"))
        }
        .onChange(of: guide.position, initial: true) { draft = Self.text(guide.position) }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { send() }
        }
    }

    private func send() {
        if let number = Double(draft.replacingOccurrences(of: ",", with: ".")), number.isFinite {
            _ = try? store.perform(guideMove: index, to: number, frame: frame)
        }
        draft = Self.text(guide.position)
    }

    /// The number with up to two decimals, with a point as the decimal sign so that it parses back.
    private static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}
