import Foundation
import ALFAcolorCore
import BoardModel

/// The settings of the app, kept in UserDefaults. One instance for the whole app.
/// Values read here at start apply after a restart; values written here apply at once where a view reads them.
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    let store = SettingsStore(backing: DefaultsSettingsBacking())

    /// The unit of the position fields.
    var lengthUnit: LengthUnit {
        get { LengthUnit(UnitChoice(rawValue: store.text(.unitDefault)) ?? .point) }
    }

    func save(lengthUnit: LengthUnit) {
        store.set(.text(UnitChoice(lengthUnit).rawValue), for: .unitDefault)
    }

    /// The step of the grid in board points, read at the start of a window.
    var gridStep: Double { store.number(.gridStep) }

    /// How many live code pages run at once, read at the start of the app.
    var playerLimit: Int { Int(store.number(.playerMaxLive)) }
}

extension LengthUnit {
    /// The unit as the settings name it.
    init(_ choice: UnitChoice) {
        switch choice {
        case .point: self = .point
        case .pixel: self = .pixel
        case .millimetre: self = .millimetre
        }
    }
}

extension UnitChoice {
    /// The settings name of a unit.
    init(_ unit: LengthUnit) {
        switch unit {
        case .point: self = .point
        case .pixel: self = .pixel
        case .millimetre: self = .millimetre
        }
    }
}
