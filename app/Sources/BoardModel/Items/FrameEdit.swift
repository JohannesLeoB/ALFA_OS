import Foundation
import ALFAcolorCore
import Geometry

/// The pixel scales that a frame can show: @1x to @3x.
public enum FrameScale {
    public static let options: [Double] = [1, 2, 3]

    /// The scale of a frame: its own, else the first scale of its device, else 2.
    public static func effective(deviceID: String?, scale: Double?) -> Double {
        if let scale { return scale }
        return deviceID.flatMap(Device.resolve)?.scales.first ?? 2
    }
}

/// Commands for frames. Moving a frame is `Command.move`, which takes the items inside it along.
/// Each command below is one undo step. A frame keeps its items: only its size and device change.
public enum FrameEdit {
    /// Adds a frame of the device, centered on the point. The frame has the orientation of the device.
    public static func insert(_ device: Device, id: ItemID = ItemID(), centerX: Double, centerY: Double, layerID: String) -> Command {
        let rect = Rect(x: (centerX - device.width / 2).rounded(), y: (centerY - device.height / 2).rounded(),
                        w: device.width, h: device.height)
        let item = Item(id: id, title: "", content: .frame(deviceID: device.id, gridID: nil), rect: rect, layerID: layerID)
        return .insert([item])
    }

    /// Changes the device of a frame. The frame takes the size of the device in its current orientation.
    /// The items inside keep their place on the board. Empty when nothing changes.
    public static func setDevice(_ item: Item, to device: Device) -> [Command] {
        guard case .frame(let current, let grid, let scale) = item.content else { return [] }
        let landscape = item.rect.w >= item.rect.h
        let target = (device.width >= device.height) == landscape ? device : device.rotated
        guard current != target.id else { return [] }
        return [
            .resize([item.id: Rect(x: item.rect.x, y: item.rect.y, w: target.width, h: target.height)]),
            .setContent(item.id, .frame(deviceID: target.id, gridID: grid, scale: scale)),
        ]
    }

    /// Turns a frame by 90 degrees: width and height swap, the top left corner stays. The items inside keep
    /// their place relative to the corner. Empty for an unknown item.
    public static func rotate(_ item: Item) -> [Command] {
        guard case .frame(let deviceID, let grid, let scale) = item.content else { return [] }
        let turned = deviceID.map { Device.resolve($0)?.rotated.id ?? $0 }
        return [
            .resize([item.id: Rect(x: item.rect.x, y: item.rect.y, w: item.rect.h, h: item.rect.w)]),
            .setContent(item.id, .frame(deviceID: turned, gridID: grid, scale: scale)),
        ]
    }

    /// Sets the pixel scale. The size in points does not change. Empty when the scale is already set.
    public static func setScale(_ item: Item, to scale: Double) -> [Command] {
        guard case .frame(let deviceID, let grid, let current) = item.content,
              FrameScale.effective(deviceID: deviceID, scale: current) != scale else { return [] }
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: grid, scale: scale))]
    }
}

extension BoardStore {
    /// Changes the device of the selected frames. One undo step. Returns false when no frame changes.
    @discardableResult
    public func perform(frameDevice device: Device) throws -> Bool {
        let commands = selectedItems.flatMap { FrameEdit.setDevice($0, to: device) }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.frame.device"))
    }

    /// Turns the selected frames. One undo step. Returns false when no frame is selected.
    @discardableResult
    public func performFrameRotation() throws -> Bool {
        let commands = selectedItems.flatMap { FrameEdit.rotate($0) }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.frame.rotate"))
    }

    /// Sets the pixel scale of the selected frames. One undo step. Returns false when nothing changes.
    @discardableResult
    public func perform(frameScale scale: Double) throws -> Bool {
        let commands = selectedItems.flatMap { FrameEdit.setScale($0, to: scale) }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.frame.scale"))
    }
}
