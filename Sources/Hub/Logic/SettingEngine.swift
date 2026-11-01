import Foundation

enum SettingEngine {
    static func decoded<V: Decodable>(_ data: Data?, as type: V.Type) -> V? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    static func durable(_ state: InletState) -> InletState {
        switch state {
        case .working: .connected(probed: .distantPast)
        case .connecting: .created
        default: state
        }
    }
}
