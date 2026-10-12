import Foundation
import CoreBluetooth

public struct LaserGeraeteProfil: Sendable {
    public let id: String
    public let displayName: String
    public let serviceUUID: CBUUID
    public let messwertCharacteristicUUID: CBUUID
    public let nameMatcher: @Sendable (String?) -> Bool
    public let decodeMeter: @Sendable (Data) -> Double?

    public init(
        id: String,
        displayName: String,
        serviceUUID: CBUUID,
        messwertCharacteristicUUID: CBUUID,
        nameMatcher: @escaping @Sendable (String?) -> Bool,
        decodeMeter: @escaping @Sendable (Data) -> Double?
    ) {
        self.id = id
        self.displayName = displayName
        self.serviceUUID = serviceUUID
        self.messwertCharacteristicUUID = messwertCharacteristicUUID
        self.nameMatcher = nameMatcher
        self.decodeMeter = decodeMeter
    }
}

public enum LaserGeraeteRegistry {
    public static let leicaDistoD110 = LaserGeraeteProfil(
        id: "leica-disto-d110",
        displayName: "Leica Disto D110",
        serviceUUID: CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94"),
        messwertCharacteristicUUID: CBUUID(string: "3AB10101-F831-4395-B29D-570977D5BF94"),
        nameMatcher: { name in name?.lowercased().contains("disto") ?? false },
        decodeMeter: LeicaDistoStatusReducer.meterAusRohwert
    )

    public static let alle: [LaserGeraeteProfil] = [leicaDistoD110]

    public static func profil(fuerAdvertisedServiceUUIDs uuids: [CBUUID], name: String?) -> LaserGeraeteProfil? {
        alle.first { profil in
            uuids.contains(profil.serviceUUID) && profil.nameMatcher(name)
        }
    }

    public static func profil(fuerName name: String?) -> LaserGeraeteProfil? {
        alle.first { $0.nameMatcher(name) }
    }
}
