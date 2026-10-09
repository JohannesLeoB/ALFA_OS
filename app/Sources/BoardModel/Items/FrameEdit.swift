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
        guard case .frame(let current, let gridID, let scale, let grid, let guides) = item.content else { return [] }
        let landscape = item.rect.w >= item.rect.h
        let target = (device.width >= device.height) == landscape ? device : device.rotated
        guard current != target.id else { return [] }
        return [
            .resize([item.id: Rect(x: item.rect.x, y: item.rect.y, w: target.width, h: target.height)]),
            .setContent(item.id, .frame(deviceID: target.id, gridID: gridID, scale: scale, grid: grid, guides: guides)),
        ]
    }

    /// Turns a frame by 90 degrees: width and height swap, the top left corner stays. The items inside keep
    /// their place relative to the corner. Empty for an unknown item.
    public static func rotate(_ item: Item) -> [Command] {
        guard case .frame(let deviceID, let gridID, let scale, let grid, let guides) = item.content else { return [] }
        let turned = deviceID.map { Device.resolve($0)?.rotated.id ?? $0 }
        return [
            .resize([item.id: Rect(x: item.rect.x, y: item.rect.y, w: item.rect.h, h: item.rect.w)]),
            .setContent(item.id, .frame(deviceID: turned, gridID: gridID, scale: scale, grid: grid, guides: guides)),
        ]
    }

    /// Turns a frame when it is not in the wanted orientation. Empty when it already is.
    public static func orient(_ item: Item, landscape: Bool) -> [Command] {
        let isLandscape = item.rect.w >= item.rect.h
        guard isLandscape != landscape else { return [] }
        return rotate(item)
    }

    /// Sets the pixel scale. The size in points does not change. Empty when the scale is already set.
    public static func setScale(_ item: Item, to scale: Double) -> [Command] {
        guard case .frame(let deviceID, let gridID, let current, let grid, let guides) = item.content,
              FrameScale.effective(deviceID: deviceID, scale: current) != scale else { return [] }
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: grid, guides: guides))]
    }
}

extension BoardStore {
    /// Adds a frame of the preset with this ID, centered on the point, and selects it. One undo step.
    /// The frame goes on the layer when that layer can take it (visible and not locked), else on the first layer that can.
    /// Returns false for an unknown preset, without an active space, or when no layer can take the frame.
    @discardableResult
    public func addFrame(deviceID: String, centerX: Double, centerY: Double, layerID: String? = nil) throws -> Bool {
        guard let device = Device.preset(deviceID), let space = activeSpace else { return false }
        let usable: (Layer) -> Bool = { !$0.locked && $0.visible }
        guard let layer = space.layers.first(where: { $0.id == layerID && usable($0) }) ?? space.layers.first(where: usable) else { return false }
        return try perform(FrameEdit.insert(device, centerX: centerX, centerY: centerY, layerID: layer.id))
    }

    /// Changes the device of the selected frames to the preset with this ID. One undo step.
    @discardableResult
    public func perform(frameDeviceID id: String) throws -> Bool {
        guard let device = Device.preset(id) else { return false }
        return try perform(frameDevice: device)
    }

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

    /// Sets the orientation of the selected frames. Frames in the wanted orientation stay. One undo step.
    @discardableResult
    public func perform(frameLandscape landscape: Bool) throws -> Bool {
        let commands = selectedItems.flatMap { FrameEdit.orient($0, landscape: landscape) }
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
