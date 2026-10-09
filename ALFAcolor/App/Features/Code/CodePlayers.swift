import Dispatch
import Foundation
import Renderers

/// The live pages of the app, in all windows. At most `player.maxLive` pages run at once: a page that starts beyond the limit stops the oldest one.
/// Under memory pressure every live page stops. One instance for the app keeps that limit true across windows.
@MainActor
final class CodePlayers {
    static let shared = CodePlayers()

    /// The number of live pages comes from the settings at the start of the app.
    private let pool = PlayerPool<UUID>(limit: AppSettings.shared.playerLimit)
    private let pressure: DispatchSourceMemoryPressure

    private init() {
        pressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        pressure.setEventHandler {
            MainActor.assumeIsolated {
                CodePlayers.shared.stopAll()
            }
        }
        pressure.resume()
    }

    /// Makes the player `id` the live one. The live player before it stops.
    func claim(_ id: UUID, stop: @escaping () -> Void) {
        pool.claim(id, stop: stop)
    }

    /// Takes a player that stopped itself out of the pool.
    func release(_ id: UUID) {
        pool.release(id)
    }

    private func stopAll() {
        pool.stopAll()
        CodeStills.shared.clearMemory()
    }
}
