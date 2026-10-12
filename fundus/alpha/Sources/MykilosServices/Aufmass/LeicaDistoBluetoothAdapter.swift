import Foundation
import CoreBluetooth
import MykilosKit

public final class LeicaDistoBluetoothAdapter: NSObject, LaserMeasuring, @unchecked Sendable {
    private var aktivesProfil: LaserGeraeteProfil?
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?

    private var scanGestartet = false
    private var zustandEmpfangen = false

    private let statusContinuation: AsyncStream<LaserVerbindungsStatus>.Continuation
    public let status: AsyncStream<LaserVerbindungsStatus>
    private let massContinuation: AsyncStream<Double>.Continuation
    public let letztesMass: AsyncStream<Double>

    override public init() {
        var statusCont: AsyncStream<LaserVerbindungsStatus>.Continuation!
        self.status = AsyncStream { statusCont = $0 }
        self.statusContinuation = statusCont

        var massCont: AsyncStream<Double>.Continuation!
        self.letztesMass = AsyncStream { massCont = $0 }
        self.massContinuation = massCont
        super.init()
    }

    public func verbinde() async throws {
        statusContinuation.yield(.sucht)
        scanGestartet = false
        zustandEmpfangen = false
        centralManager = CBCentralManager(delegate: self, queue: nil)
        pruefeUndScanne(versuch: 0)
    }

    private func pruefeUndScanne(versuch: Int) {
        guard scanGestartet == false, zustandEmpfangen == false, let c = centralManager else { return }
        switch LeicaDistoStatusReducer.fuerManagerState(c.state) {
        case .weiterScannen where c.state == .poweredOn:
            starteScan(c)
        case .melden(let status):
            statusContinuation.yield(status)
        default:
            if versuch < 16 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.pruefeUndScanne(versuch: versuch + 1)
                }
            }
        }
    }

    private func starteScan(_ c: CBCentralManager) {
        guard scanGestartet == false else { return }
        scanGestartet = true
        c.scanForPeripherals(withServices: nil, options: nil)
    }

    public func trenne() async {
        if let peripheral, let centralManager {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        centralManager = nil
        peripheral = nil
        aktivesProfil = nil
        statusContinuation.yield(.getrennt)
    }
}

extension LeicaDistoBluetoothAdapter: CBCentralManagerDelegate, CBPeripheralDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        zustandEmpfangen = true
        switch LeicaDistoStatusReducer.fuerManagerState(central.state) {
        case .weiterScannen:
            starteScan(central)
        case .melden(let status):
            statusContinuation.yield(status)
        }
    }

    public func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        guard let profil = LaserGeraeteRegistry.profil(fuerName: name) else {
            return
        }
        aktivesProfil = profil
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusContinuation.yield(.gekoppelt(geraetename: peripheral.name ?? "Laser"))
        guard let profil = aktivesProfil else { return }
        peripheral.discoverServices([profil.serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusContinuation.yield(.error(error?.localizedDescription ?? "Verbindung fehlgeschlagen"))
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusContinuation.yield(.getrennt)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first, let profil = aktivesProfil else { return }
        peripheral.discoverCharacteristics([profil.messwertCharacteristicUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristic = service.characteristics?.first else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value,
              let meter = aktivesProfil?.decodeMeter(data) else { return }
        massContinuation.yield(meter)
    }
}

enum LeicaDistoStatusReducer {
    enum ManagerAktion: Equatable {
        case weiterScannen
        case melden(LaserVerbindungsStatus)
    }

    static func fuerManagerState(_ state: CBManagerState) -> ManagerAktion {
        switch state {
        case .poweredOn: return .weiterScannen
        case .poweredOff: return .melden(.error("Bluetooth ist ausgeschaltet"))
        case .unauthorized: return .melden(.error("Bluetooth-Zugriff nicht erlaubt"))
        case .unsupported: return .melden(.error("Bluetooth wird nicht unterstützt"))
        default: return .melden(.sucht)
        }
    }

    static func meterAusRohwert(_ data: Data) -> Double? {
        guard data.count >= 4 else { return nil }
        let bits = data.prefix(4).reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let value = Double(Float(bitPattern: bits))
        guard value.isFinite, value >= 0 else { return nil }
        return value
    }
}
