import Design
import SwiftUI

private struct ReelEffect: GeometryEffect {
    var angle: Double
    let bottom: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let pivotX = size.width / 2
        let pivotY = bottom ? size.height : 0
        var form = CATransform3DIdentity
        form.m34 = -1 / CGFloat(Tokens.Size.menuReelPerspective)
        form = CATransform3DRotate(form, CGFloat(angle * .pi / SheetValues.halfTurn), 1, 0, 0)
        let toPivot = CATransform3DMakeTranslation(-pivotX, -pivotY, 0)
        let back = CATransform3DMakeTranslation(pivotX, pivotY, 0)
        return ProjectionTransform(CATransform3DConcat(CATransform3DConcat(toPivot, form), back))
    }
}

extension View {
    func reel(angle: Double, bottom: Bool) -> some View {
        modifier(ReelEffect(angle: angle, bottom: bottom))
    }
}
