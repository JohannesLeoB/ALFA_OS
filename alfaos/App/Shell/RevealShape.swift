import SwiftUI

struct RevealShape: Shape {
    var progress: Double
    var fromTop: Bool
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let height = rect.height * CGFloat(progress)
        let shown = CGRect(x: rect.minX, y: fromTop ? rect.minY : rect.maxY - height, width: rect.width, height: height)
        return RoundedRectangle(cornerRadius: radius).path(in: shown)
    }
}
