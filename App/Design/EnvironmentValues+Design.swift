import SwiftUI

private struct AppearanceKey: EnvironmentKey {
    static let defaultValue = Appearance(dark: false, still: false)
}

private struct NarrowCardKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PillRoomKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var appearance: Appearance {
        get { self[AppearanceKey.self] }
        set { self[AppearanceKey.self] = newValue }
    }

    var narrowCard: Bool {
        get { self[NarrowCardKey.self] }
        set { self[NarrowCardKey.self] = newValue }
    }

    var pillRoom: CGFloat? {
        get { self[PillRoomKey.self] }
        set { self[PillRoomKey.self] = newValue }
    }
}
