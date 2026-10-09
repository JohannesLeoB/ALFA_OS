import SwiftUI
import ALFAcolorCore
import BoardModel

/// The sections that a kind adds to the inspector. A brief that gives a kind its own fields registers its section here.
@MainActor
enum KindInspectors {
    private static let sections: [ItemKind: (BoardStore, [Item]) -> AnyView] = [
        .image: { store, items in AnyView(ImageFitSection(store: store, items: items)) },
        .frame: { store, items in AnyView(FrameSection(store: store, items: items)) },
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
            Picker("inspector.fit", selection: Binding<ImageFit?>(
                get: { shared.value },
                set: { fit in if let fit { _ = try? store.perform(imageFit: fit) } }
            )) {
                if shared == .mixed { Text("inspector.mixed").tag(ImageFit?.none) }
                Text("inspector.fit.fit").tag(ImageFit?.some(.fit))
                Text("inspector.fit.fill").tag(ImageFit?.some(.fill))
            }
            .pickerStyle(.segmented)
            PictureColorsButton(store: store, items: items)
        }
    }
}

/// The device, the orientation and the scale of the selected frames. A single frame also shows its pixel size.
struct FrameSection: View {
    var store: BoardStore
    var items: [Item]

    var body: some View {
        let displays = items.compactMap { item -> FrameDisplay? in
            guard case .frame(let deviceID, _, let scale, _, _) = item.content else { return nil }
            return FrameDisplay.make(deviceID: deviceID, scale: scale, rect: item.rect)
        }
        let devices = SharedValue(displays.compactMap(\.presetID))
        let orientation = SharedValue(displays.map(\.isLandscape))
        let scales = SharedValue(displays.map(\.scale))
        Section("item.kind.frame") {
            Picker("inspector.frame.device", selection: Binding<String?>(
                get: { devices.value },
                set: { id in
                    if let id { _ = try? store.perform(frameDeviceID: id) }
                })) {
                if devices == .mixed { Text("inspector.mixed").tag(String?.none) }
                ForEach(DeviceChoice.all) { choice in
                    Text(LocalizedStringKey(choice.nameKey)).tag(String?.some(choice.id))
                }
            }
            Picker("inspector.frame.orientation", selection: Binding<Bool?>(
                get: { orientation.value },
                set: { landscape in
                    if let landscape { _ = try? store.perform(frameLandscape: landscape) }
                })) {
                if orientation == .mixed { Text("inspector.mixed").tag(Bool?.none) }
                Text("inspector.frame.landscape").tag(Bool?.some(true))
                Text("inspector.frame.portrait").tag(Bool?.some(false))
            }
            .pickerStyle(.segmented)
            Picker("inspector.frame.scale", selection: Binding<Int?>(
                get: { scales.value },
                set: { value in
                    if let value { _ = try? store.perform(frameScale: Double(value)) }
                })) {
                if scales == .mixed { Text("inspector.mixed").tag(Int?.none) }
                ForEach(FrameScale.options.map { Int($0) }, id: \.self) { option in
                    Text(verbatim: "@\(option)x").tag(Int?.some(option))
                }
            }
            .pickerStyle(.segmented)
            if displays.count == 1, let frame = displays.first {
                LabeledContent("inspector.frame.pixels") {
                    Text("frame.size.px \(frame.widthPixels) \(frame.heightPixels) \(frame.scale)")
                }
            }
            if displays.contains(where: \.isTemplate) {
                Text("frame.template")
                    .foregroundStyle(.secondary)
            }
            FrameGridSection(store: store, items: items)
            GuideSection(store: store, items: items)
        }
    }
}
