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

    public var isLandscape: Bool { widthPoints >= heightPoints }
    /// The size in pixels at the scale of the frame.
    public var widthPixels: Int { widthPoints * scale }
    public var heightPixels: Int { heightPoints * scale }

    public static func make(deviceID: String?, scale: Double?, rect: Rect) -> FrameDisplay {
        let device = deviceID.flatMap(Device.resolve)
        return FrameDisplay(
            deviceID: deviceID,
            nameKey: device?.name,
            presetID: deviceID.map(Device.baseID(of:)),
            widthPoints: Int(rect.w.rounded()),
            heightPoints: Int(rect.h.rounded()),
            scale: Int(FrameScale.effective(deviceID: deviceID, scale: scale).rounded()),
            isTemplate: device?.isTemplate ?? false)
    }
}
