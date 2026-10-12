import Foundation

public struct LaserDiagnoseCharacteristic: Identifiable, Sendable, Equatable {
    public let uuid: String
    public let eigenschaften: [String]
    public var letzteRohdatenHex: String?
    public var moeglicheMeter: Double?
    public var id: String { uuid }

    public init(uuid: String, eigenschaften: [String],
                letzteRohdatenHex: String? = nil, moeglicheMeter: Double? = nil) {
        self.uuid = uuid
        self.eigenschaften = eigenschaften
        self.letzteRohdatenHex = letzteRohdatenHex
        self.moeglicheMeter = moeglicheMeter
    }
}

public struct LaserDiagnoseService: Identifiable, Sendable, Equatable {
    public let uuid: String
    public var characteristics: [LaserDiagnoseCharacteristic]
    public var id: String { uuid }

    public init(uuid: String, characteristics: [LaserDiagnoseCharacteristic] = []) {
        self.uuid = uuid
        self.characteristics = characteristics
    }
}

public struct LaserDiagnoseBericht: Sendable, Equatable {
    public var phase: String
    public var geraeteName: String?
    public var services: [LaserDiagnoseService]

    public init(phase: String, geraeteName: String? = nil, services: [LaserDiagnoseService] = []) {
        self.phase = phase
        self.geraeteName = geraeteName
        self.services = services
    }

    public var alsText: String {
        var rowItems = ["LASER-BLE-DIAGNOSE", "Gerät: \(geraeteName ?? "—")", "Phase: \(phase)", ""]
        for s in services {
            rowItems.append("Service \(s.uuid)")
            for c in s.characteristics {
                var z = "  · Char \(c.uuid) [\(c.eigenschaften.joined(separator: ","))]"
                if let hex = c.letzteRohdatenHex { z += "  Rohdaten: \(hex)" }
                if let m = c.moeglicheMeter { z += String(format: "  ≈ %.3f m", m) }
                rowItems.append(z)
            }
        }
        return rowItems.joined(separator: "\n")
    }
}

public enum LaserPayloadDeutung {
    public static func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    public static func float32LE(_ data: Data) -> Double? {
        guard data.count >= 4 else { return nil }
        let b = [UInt8](data)
        let bits = UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
        let f = Float(bitPattern: bits)
        guard f.isFinite, f >= 0, f < 200 else { return nil }
        return Double(f)
    }
}
