import Foundation
import Network

@MainActor
@Observable
public final class NetworkPathMonitor {
    public private(set) var online: Bool = true
    public private(set) var seit: Date = Date()

    private let monitor = NWPathMonitor()
    private let schlange = DispatchQueue(label: "mykilos.netzwaechter")

    public init(starten: Bool = true) {
        if starten { starte() }
    }

    public func starte() {
        monitor.pathUpdateHandler = { [weak self] pfad in
            let jetztOnline = pfad.status == .satisfied
            Task { @MainActor in self?.uebernimm(jetztOnline) }
        }
        monitor.start(queue: schlange)
    }

    public func uebernimm(_ jetztOnline: Bool, wann: Date = Date()) {
        guard jetztOnline != online else { return }
        online = jetztOnline
        seit = wann
    }

    deinit { monitor.cancel() }
}
