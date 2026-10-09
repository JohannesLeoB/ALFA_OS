import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The rulers along the top and left edge of the canvas. They measure from the corner of the frame that holds
/// the selection, else the frame under the pointer, else the frame used last. Only the strips take clicks.
struct RulersOverlay: View {
    var canvas: CanvasController
    var shell: ShellState
    /// Canvas position of the top left corner of this overlay, in canvas points.
    var lead: CGPoint

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let thickness = theme.space(.s6)
        let picked = RulerOrigin.pick(items: canvas.store.activeSpace?.items ?? [],
                                      selection: canvas.store.selection, pointer: nil, last: shell.rulerFrame)
        let viewport = canvas.viewport
        let scale = RulerScale.make(unit: shell.lengthUnit, zoom: viewport.zoom, scale: picked?.scale ?? 1)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: thickness, height: thickness)
                    .allowsHitTesting(false)
                RulerView(along: .horizontal, scale: scale, origin: picked?.x ?? 0, viewport: viewport,
                          lead: lead.x + thickness, onPickUnit: { shell.lengthUnit = $0 })
                    .frame(maxWidth: .infinity, minHeight: thickness, maxHeight: thickness)
            }
            HStack(spacing: 0) {
                RulerView(along: .vertical, scale: scale, origin: picked?.y ?? 0, viewport: viewport,
                          lead: lead.y + thickness, onPickUnit: { shell.lengthUnit = $0 })
                    .frame(minWidth: thickness, maxWidth: thickness, maxHeight: .infinity)
                Color.clear
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: picked?.id) { _, id in
            shell.rulerFrame = id
        }
    }
}
