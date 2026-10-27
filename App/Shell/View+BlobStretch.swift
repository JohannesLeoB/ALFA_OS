import Shell
import SwiftUI

private struct BlobStretchEffect: GeometryEffect {
    var stretch: BlobStretch
    var squeeze: Double

    var animatableData: Double {
        get { squeeze }
        set { squeeze = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let center = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
        let scaleX = (1 + stretch.amount) * squeeze
        let scaleY = 1 / (1 + stretch.amount) * squeeze
        let form = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(rotationAngle: -stretch.angle))
            .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
            .concatenating(CGAffineTransform(rotationAngle: stretch.angle))
            .concatenating(center)
        return ProjectionTransform(form)
    }
}

extension View {
    func blobStretch(_ stretch: BlobStretch, squeeze: Double) -> some View {
        modifier(BlobStretchEffect(stretch: stretch, squeeze: squeeze))
    }
}
