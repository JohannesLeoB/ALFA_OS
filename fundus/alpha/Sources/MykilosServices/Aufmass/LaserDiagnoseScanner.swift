import Foundation
import CoreBluetooth
import MykilosKit

public final class LaserDiagnoseScanner: NSObject, @unchecked Sendable {
    public let berichte: AsyncStream<LaserDiagnoseBericht>
    private let cont: AsyncStream<LaserDiagnoseBericht>.Continuation
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var bericht = LaserDiagnoseBericht(phase: "idle")

    private var zustandEmpfangen = false

    private var gescannt = false

    private static let namensMuster = ["disto", "leica", "bosch", "glm", "laser"]

    public override init() {
        var c: AsyncStream<LaserDiagnoseBericht>.Continuation!
        self.berichte = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c = $0 }
        self.cont = c
        super.init()
    }

    public func starte() {
        bericht = LaserDiagnoseBericht(phase: "Bluetooth wird gestartet …")
        sende()
        central = CBCentralManager(delegate: self, queue: nil)

        pruefeBereitschaft(versuch: 0)
    }

    private func pruefeBereitschaft(versuch: Int) {
        guard gescannt == false, zustandEmpfangen == false, let c = central else { return }
        switch c.state {
        case .poweredOn:     starteScan(c)
        case .poweredOff:    bericht.phase = "Bluetooth ist aus (Mac)."; sende()
        case .unauthorized:  bericht.phase = "Bluetooth-Berechtigung fehlt."; sende()
        case .unsupported:   bericht.phase = "Bluetooth wird nicht unterstützt."; sende()
        default:
            if versuch >= 16 {
                bericht.phase = "Bluetooth nicht bereit (State=\(c.state.rawValue))."; sende()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.pruefeBereitschaft(versuch: versuch + 1)
                }
            }
        }
    }

    private func starteScan(_ c: CBCentralManager) {
        guard gescannt == false else { return }
        gescannt = true
        bericht.phase = "Suche Laser-Gerät … (Gerät einschalten, Bluetooth-Taste drücken)"
        sende()
        c.scanForPeripherals(withServices: nil, options: nil)
    }

    public func stoppe() {
        central?.stopScan()
        if let peripheral, let central { central.cancelPeripheralConnection(peripheral) }
        central = nil
        peripheral = nil
        bericht.phase = "gestoppt"
        sende()
        cont.finish()
    }

    private func sende() { cont.yield(bericht) }
}

extension LaserDiagnoseScanner: CBCentralManagerDelegate, CBPeripheralDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        zustandEmpfangen = true
        switch central.state {
        case .poweredOn:     starteScan(central)
        case .poweredOff:    bericht.phase = "Bluetooth ist aus (Mac)."; sende()
        case .unauthorized:  bericht.phase = "Bluetooth-Berechtigung fehlt."; sende()
        case .unsupported:   bericht.phase = "Bluetooth wird nicht unterstützt."; sende()
        default:             bericht.phase = "Bluetooth nicht bereit (State=\(central.state.rawValue)) …"; sende()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = (peripheral.name ?? advName ?? "").lowercased()
        guard Self.namensMuster.contains(where: { name.contains($0) }) else { return }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        bericht.geraeteName = peripheral.name ?? advName
        bericht.phase = "Verbinde mit \(bericht.geraeteName ?? "Gerät") …"
        sende()
        central.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        bericht.phase = "Verbunden — erkunde Services …"
        sende()
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        bericht.phase = "Verbindung fehlgeschlagen: \(error?.localizedDescription ?? "unbekannt")"
        sende()
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        bericht.phase = "Getrennt."
        sende()
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] {
            if bericht.services.contains(where: { $0.uuid == s.uuid.uuidString }) == false {
                bericht.services.append(LaserDiagnoseService(uuid: s.uuid.uuidString))
            }
            peripheral.discoverCharacteristics(nil, for: s)
        }
        bericht.phase = "\(bericht.services.count) Services — erkunde Characteristics …"
        sende()
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let idx = bericht.services.firstIndex(where: { $0.uuid == service.uuid.uuidString }) else { return }
        for c in service.characteristics ?? [] {
            if bericht.services[idx].characteristics.contains(where: { $0.uuid == c.uuid.uuidString }) == false {
                bericht.services[idx].characteristics.append(
                    LaserDiagnoseCharacteristic(uuid: c.uuid.uuidString, eigenschaften: eigenschaften(c.properties)))
            }
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: c)
            }
        }
        bericht.phase = "Bereit — jetzt am Gerät messen (Roh-Payloads erscheinen unten)."
        sende()
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let hex = LaserPayloadDeutung.hex(data)
        let meter = LaserPayloadDeutung.float32LE(data)
        for si in bericht.services.indices {
            if let ci = bericht.services[si].characteristics.firstIndex(where: { $0.uuid == characteristic.uuid.uuidString }) {
                bericht.services[si].characteristics[ci].letzteRohdatenHex = hex
                bericht.services[si].characteristics[ci].moeglicheMeter = meter
            }
        }
        sende()
    }

    private func eigenschaften(_ p: CBCharacteristicProperties) -> [String] {
        var out: [String] = []
        if p.contains(.read) { out.append("read") }
        if p.contains(.write) { out.append("write") }
        if p.contains(.writeWithoutResponse) { out.append("writeNoResp") }
        if p.contains(.notify) { out.append("notify") }
        if p.contains(.indicate) { out.append("indicate") }
        return out
    }
}
