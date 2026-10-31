import Hub

extension LinkState {
    var connection: ConnectionState {
        switch self {
        case .connected: .connected
        case .connecting: .connecting
        case .working: .working
        case .notConnected: .notConnected
        case .failed: .failed
        case .unreadable: .unreadable
        }
    }
}
