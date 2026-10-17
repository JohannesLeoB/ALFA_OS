import ShellCore
import SwiftUI

struct BlobView: View {
    let theme: Theme
    let model: ShellModel
    @Binding var dragCenter: CGPoint?
    @State private var grab: CGSize?

    var body: some View {
        let g = theme.geometry
        let width = CGFloat(model.blobWidth)
        let height = CGFloat(g.blobHeight)
        let origin = model.blobOrigin
        let awake = model.phase != .rest
        let held = dragCenter != nil
        let x = dragCenter.map { $0.x - width / 2 } ?? CGFloat(origin.x)
        let y = dragCenter.map { $0.y - height / 2 } ?? CGFloat(origin.y)
        let shiftsLeft = model.blob.edge == .trailing
        let anchorX = shiftsLeft ? x - (width - CGFloat(g.blobWidth)) : x

        HStack(spacing: theme.length(.spaceS)) {
            face
            theme.text(model.current?.titleKey ?? "")
                .font(theme.font(.callout))
                .lineLimit(1)
                .fixedSize()
                .opacity(awake ? 1 : 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.length(.spaceXs))
        .frame(width: width, height: height, alignment: .leading)
        .foregroundStyle(theme.design(\.onInverse))
        .background(Capsule().fill(theme.design(\.inverse)))
        .clipShape(Capsule())
        .themeShadow(theme, layers: theme.designShadow(\.floating), shape: Capsule())
        .offset(x: anchorX, y: y)
        .animation(held ? nil : theme.spring(Design.Duration.blobWidth), value: width)
        .animation(held ? nil : theme.spring(Design.Duration.blobFlight, bounce: 0.2), value: model.blob)
        .onHover { model.setHovering($0) }
        .gesture(drag)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { model.toggleAssistant() }
                .exclusively(before: TapGesture().onEnded { model.toggleMenu() })
        )
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(theme.text("blob.label"))
    }

    private var face: some View {
        let size = theme.length(.sizeControlM)
        return ZStack {
            Circle().strokeBorder(theme.design(\.onInverse), lineWidth: theme.length(.strokeHairline))
            HStack(spacing: CGFloat(Design.Size.blobEyeGap)) {
                eye
                eye
            }
        }
        .frame(width: size, height: size)
    }

    private var eye: some View {
        Capsule()
            .fill(theme.design(\.onInverse))
            .frame(width: CGFloat(Design.Size.blobEyeWidth), height: CGFloat(Design.Size.blobEyeHeight))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: theme.length(.spaceXs), coordinateSpace: .named("shell"))
            .onChanged { value in
                if grab == nil {
                    let origin = model.blobOrigin
                    let center = CGPoint(
                        x: CGFloat(origin.x + model.blobWidth / 2),
                        y: CGFloat(origin.y + theme.geometry.blobHeight / 2)
                    )
                    grab = CGSize(width: value.startLocation.x - center.x, height: value.startLocation.y - center.y)
                    model.closeMenu()
                    model.closeAssistant()
                }
                let offset = grab ?? .zero
                dragCenter = CGPoint(x: value.location.x - offset.width, y: value.location.y - offset.height)
            }
            .onEnded { value in
                let offset = grab ?? .zero
                let center = Point(x: Double(value.location.x - offset.width), y: Double(value.location.y - offset.height))
                grab = nil
                model.dropBlob(center: center, velocity: Point(x: Double(value.velocity.width), y: Double(value.velocity.height)))
                dragCenter = nil
            }
    }
}

struct PersonPillView: View {
    let theme: Theme

    var body: some View {
        let height = theme.length(.componentBlobHeight)
        HStack(spacing: theme.length(.spaceXs)) {
            circle(.strokeRing) { Image(systemName: "arrow.triangle.2.circlepath").font(theme.font(.mark)) }
            circle(.strokeHairline) { theme.text("person.initials").font(theme.font(.mark)) }
        }
        .padding(.horizontal, theme.length(.spaceXs))
        .frame(height: height)
        .foregroundStyle(theme.design(\.onInverse))
        .background(Capsule().fill(theme.design(\.inverse)))
        .themeShadow(theme, layers: theme.designShadow(\.floating), shape: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text("pill.label"))
    }

    private func circle<Content: View>(_ stroke: ThemeKey, @ViewBuilder _ content: () -> Content) -> some View {
        let size = theme.length(.sizeControlM)
        return content()
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(theme.color(.paletteGray400), lineWidth: theme.length(stroke)))
    }
}
