import Foundation
import ALFAcolorCore
import Geometry

/// What a frame shows: its device, its size in points and in pixels at its scale. It holds no view and no theme value.
public struct FrameDisplay: Equatable, Sendable {
    /// The device as the frame stores it, for example "mbp14-portrait". nil for a frame without a device.
    public var deviceID: String?
    /// The key in the string catalog of the device name, including the orientation. nil without a device.
    public var nameKey: String?
    /// The ID of the preset without orientation, for example "mbp14". Used to choose the device.
    public var presetID: String?
    /// The size in points, taken from the frame.
    public var widthPoints: Int
    public var heightPoints: Int
    /// The pixels per point, 1 to 3.
    public var scale: Int
    /// True for a device that Apple's own page does not confirm.
    public var isTemplate: Bool
    /// The lines of the column grid, nil without a grid.
    public var gridLines: FrameGridLines? = nil
    /// True when the frame shows its size in pixels: it has a device, or a scale of its own. A free frame without
    /// a scale shows points only, so that no pixel scale is invented for it.
    public var showsPixels: Bool = true

    public var isLandscape: Bool { widthPoints >= heightPoints }
    /// The size in pixels at the scale of the frame.
    public var widthPixels: Int { Self.pixels(widthPoints, scale) }
    public var heightPixels: Int { Self.pixels(heightPoints, scale) }

    /// Points times scale. A product beyond the Int range stays at the range limit instead of trapping.
    private static func pixels(_ points: Int, _ scale: Int) -> Int {
        let (product, overflow) = points.multipliedReportingOverflow(by: scale)
        guard overflow else { return product }
        return (points < 0) == (scale < 0) ? Int.max : Int.min
    }

    public static func make(deviceID: String?, scale: Double?, rect: Rect, grid: ColumnGrid? = nil) -> FrameDisplay {
        let device = deviceID.flatMap(Device.resolve)
        return FrameDisplay(
            deviceID: deviceID,
            nameKey: device?.name,
            presetID: deviceID.map(Device.baseID(of:)),
            widthPoints: clampedLength(rect.w).clampedInt,
            heightPoints: clampedLength(rect.h).clampedInt,
            scale: FrameScale.effective(deviceID: deviceID, scale: scale).clampedInt,
            isTemplate: device?.isTemplate ?? false,
            gridLines: grid.flatMap { FrameGridLines.make($0, width: rect.w, height: rect.h) },
            showsPixels: deviceID != nil || scale != nil)
    }
}

/// A preset that a frame can take, for the device choice of the inspector.
public struct DeviceChoice: Identifiable, Sendable {
    /// The ID of the preset without orientation.
    public var id: String
    /// The key of the name in the string catalog.
    public var nameKey: String

    /// The presets in the order of the device list.
    public static let all: [DeviceChoice] = Device.presets.map { DeviceChoice(id: $0.id, nameKey: $0.name) }
}
