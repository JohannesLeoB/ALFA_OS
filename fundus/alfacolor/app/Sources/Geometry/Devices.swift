import Foundation
import ALFAcolorCore

// The device list for frames. Sizes are in points (pt). `scales` lists the pixels per point of the device.
//
// Sources, checked on 2026-10-09 against Apple's pages:
// - https://www.apple.com/macbook-pro/specs/ : 14 inch 3024 x 1964 px native at 254 ppi, 16 inch 3456 x 2234 px.
//   Points are the native pixels divided by 2.
// - https://www.apple.com/macbook-air/specs/ : 13 inch 2560 x 1664 px native at 224 ppi, 15 inch 2880 x 1864 px.
//   The default scaled size is not on the page, so the Air rows are templates.
// - https://www.apple.com/ipad-air/specs/ : iPad Air 11 inch 2360 x 1640 px at 264 ppi, 13 inch 2732 x 2048 px at 264 ppi.
// - https://www.apple.com/ipad-11/specs/ : iPad 11 inch 2360 x 1640 px at 264 ppi.
// - https://www.apple.com/iphone-16/specs/ : 2556 x 1179 px at 460 ppi, which is 393 x 852 pt at 3x.
// - https://support.apple.com/en-us/121202 : Apple Watch Series 10, 46 mm 416 x 496 px and 42 mm 374 x 446 px, at 2x.
// The iPhone 16 Pro and Pro Max sizes come from third-party device lists, because Apple's page could not be read.
// Rows with `template: true` are not confirmed by Apple's own page. Check them before release.
extension Device {
    /// The start list. `name` is a key of the string catalog; the rotated name has the suffix `.rotated`.
    public static let presets: [Device] = [
        Device(id: "mbp14", name: "device.mbp14", width: 1512, height: 982, scales: [2]),
        Device(id: "mbp16", name: "device.mbp16", width: 1728, height: 1117, scales: [2]),
        Device(id: "mba13", name: "device.mba13", width: 1470, height: 956, scales: [2], template: true),
        Device(id: "mba15", name: "device.mba15", width: 1440, height: 932, scales: [2], template: true),
        Device(id: "mac-window", name: "device.macWindow", width: 1280, height: 800, scales: [2], template: true),
        Device(id: "ipad-11", name: "device.ipad11", width: 1180, height: 820, scales: [2]),
        Device(id: "ipad-air-13", name: "device.ipadAir13", width: 1366, height: 1024, scales: [2]),
        Device(id: "iphone", name: "device.iphone", width: 393, height: 852, scales: [3]),
        Device(id: "iphone-16-pro", name: "device.iphone16Pro", width: 402, height: 874, scales: [3], template: true),
        Device(id: "iphone-16-pro-max", name: "device.iphone16ProMax", width: 440, height: 956, scales: [3], template: true),
        Device(id: "watch-42", name: "device.watch42", width: 187, height: 223, scales: [2]),
        Device(id: "watch-46", name: "device.watch46", width: 208, height: 248, scales: [2])
    ]

    /// The preset with this base ID, without orientation.
    public static func preset(_ baseID: String) -> Device? {
        presets.first { $0.id == baseID }
    }

    /// The device for an ID as a frame stores it. The ID may end in `-landscape` or `-portrait`, which sets the orientation.
    /// nil for an unknown ID.
    public static func resolve(_ id: String) -> Device? {
        let suffixes = ["-landscape", "-portrait"]
        guard let suffix = suffixes.first(where: { id.hasSuffix($0) }) else { return preset(id) }
        guard let base = preset(baseID(of: id)) else { return nil }
        let wantsLandscape = suffix == "-landscape"
        return (base.width >= base.height) == wantsLandscape ? base : base.rotated
    }

    /// The ID without its orientation suffix, for example "mbp14" for "mbp14-portrait".
    public static func baseID(of id: String) -> String {
        for suffix in ["-landscape", "-portrait"] where id.hasSuffix(suffix) {
            return String(id.dropLast(suffix.count))
        }
        return id
    }
}
