import MykilosKit

@MainActor
public protocol AuthModule: AnyObject {
    associatedtype Status: AuthStatusValue
    var status: Status { get }
    func disconnect() throws
}

public extension AuthModule {
    var connectionState: ConnectionState { status.connectionState }

    func disconnecting(returning cleared: [String: String] = [:]) throws -> [String: String] {
        try disconnect()
        return cleared
    }
}

extension GoogleAuthService: AuthModule {}
extension AirtableAuthService: AuthModule {}
extension ClickUpAuthService: AuthModule {}
extension SevdeskAuthService: AuthModule {}
extension ClaudeAuthService: AuthModule {}
extension ClockodoAuthService: AuthModule {}
