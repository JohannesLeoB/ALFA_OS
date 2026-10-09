import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The rulers along the top and left edge of the canvas, the guides of the frames, and the guide that is being
/// pulled out of a ruler. The rulers measure from the corner of the frame that holds the selection, else the frame
/// that was used last. Only the strips of the rulers and the guides take clicks.
struct RulersOverlay: View {
    var canvas: CanvasController
    var shell: ShellState
    /// Canvas position of the top left corner of this overlay, in canvas points.
    var lead: CGPoint

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    /// The guide being pulled, its axis and the pointer in canvas points. nil when none is pulled.
    @State private var pulled: (axis: GuideAxis, pointer: CGPoint)?

    var body: some View {
        let thickness = theme.space(.s6)
        let picked = RulerOrigin.pick(items: canvas.store.activeSpace?.items ?? [],
                                      selection: canvas.store.selection, pointer: nil, last: shell.rulerFrame)
        let viewport = canvas.viewport
        let scale = RulerScale.make(unit: shell.lengthUnit, zoom: viewport.zoom, scale: picked?.scale ?? 1)
        ZStack(alignment: .topLeading) {
            GuidesLayer(canvas: canvas, shell: shell, lead: lead)
            if let pulled {
                pullLine(pulled.axis, at: pulled.pointer, thickness: thickness)
            }
            if shell.rulersVisible {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: thickness, height: thickness)
                        .allowsHitTesting(false)
                    RulerView(along: .horizontal, scale: scale, origin: picked?.x ?? 0, viewport: viewport,
                              lead: lead.x + thickness, cross: lead.y, onPickUnit: { shell.lengthUnit = $0 },
                              onPull: pullFrom(.horizontal))
                        .frame(maxWidth: .infinity, minHeight: thickness, maxHeight: thickness)
                }
                HStack(spacing: 0) {
                    RulerView(along: .vertical, scale: scale, origin: picked?.y ?? 0, viewport: viewport,
                              lead: lead.y + thickness, cross: lead.x, onPickUnit: { shell.lengthUnit = $0 },
                              onPull: pullFrom(.vertical))
                        .frame(minWidth: thickness, maxWidth: thickness, maxHeight: .infinity)
                    Color.clear
                        .allowsHitTesting(false)
                }
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: picked?.id) { _, id in
            shell.rulerFrame = id
        }
    }

    /// The pull of a ruler, or nil while the guides are locked. The line follows the pointer; letting go puts
    /// the guide on the frame under it.
    private func pullFrom(_ axis: GuideAxis) -> ((CGPoint, Bool) -> Void)? {
        guard !shell.guidesLocked else { return nil }
        return { pointer, ended in
            if ended {
                pulled = nil
                let board = canvas.viewport.boardPoint(canvasX: pointer.x, canvasY: pointer.y)
                guard let drop = FrameGuides.drop(axis: axis, at: board.x, board.y,
                                                  in: canvas.store.activeSpace?.items ?? []) else { return }
                _ = try? canvas.store.perform(guideAdd: drop.guide, frame: drop.frame)
            } else {
                pulled = (axis, pointer)
            }
        }
    }

    /// The pixel scale of a frame, which the unit of its guide label needs.
    private func scale(of id: ItemID) -> Double {
        guard let item = canvas.store.item(id), case .frame(let device, _, let own, _, _) = item.content else { return 1 }
        return FrameScale.effective(deviceID: device, scale: own)
    }

    /// The line of the guide being pulled, with its position in the unit of the rulers when a frame holds the pointer.
    private func pullLine(_ axis: GuideAxis, at pointer: CGPoint, thickness: CGFloat) -> some View {
        let viewport = canvas.viewport
        let board = viewport.boardPoint(canvasX: pointer.x, canvasY: pointer.y)
        let drop = FrameGuides.drop(axis: axis, at: board.x, board.y, in: canvas.store.activeSpace?.items ?? [])
        let coral = theme.color(.coral, scheme)
        return ZStack(alignment: .topLeading) {
            Canvas { context, size in
                var path = Path()
                switch axis {
                case .horizontal:
                    path.move(to: CGPoint(x: 0, y: pointer.y - lead.y))
                    path.addLine(to: CGPoint(x: size.width, y: pointer.y - lead.y))
                case .vertical:
                    path.move(to: CGPoint(x: pointer.x - lead.x, y: 0))
                    path.addLine(to: CGPoint(x: pointer.x - lead.x, y: size.height))
                }
                context.stroke(path, with: .color(coral), lineWidth: SelectionStyle.lineWidth)
            }
            if let drop {
                Text(verbatim: shell.lengthUnit.text(points: drop.guide.position, scale: scale(of: drop.frame)))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(coral)
                    .position(x: pointer.x - lead.x + thickness, y: pointer.y - lead.y - thickness)
            }
        }
        .allowsHitTesting(false)
    }
}
