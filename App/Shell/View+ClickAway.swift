import AppKit
import SwiftUI

extension View {
    func clickAway(active: Bool, inside: CGRect, perform away: @escaping () -> Void) -> some View {
        eventMonitor(.leftMouseDown, active: active) { sample in
            if let local = sample.local, !inside.contains(local) { away() }
            return false
        }
    }
}
