import Foundation
import Synchronization

/// Whether the script host of web cards answers. Tests that load React cards use it to skip when the network is off.
public enum CardNetwork {
    /// The script that a React card needs first. An answer from it means the card scripts can load.
    static let probeAddress = URL(string: "https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.26.4/babel.min.js")!

    /// Longest wait for the probe, in seconds.
    static let probeLimit = 8.0

    /// Set to 1 to act as if the network were off. The live tests then skip, and the network is not touched.
    static let offlineVariable = "ALFACOLOR_TEST_OFFLINE"

    /// True when the probe address answers with HTTP 200. The probe runs once per process, when a test first asks.
    public static let reachable: Bool = {
        if ProcessInfo.processInfo.environment[offlineVariable] == "1" { return false }
        return answers(probeAddress, within: probeLimit)
    }()

    /// Sends a HEAD request and waits for the answer, up to `seconds`. Anything but HTTP 200 counts as no.
    static func answers(_ url: URL, within seconds: Double) -> Bool {
        var request = URLRequest(url: url, timeoutInterval: seconds)
        request.httpMethod = "HEAD"
        let answer = Mutex(false)
        let done = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            let ok = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            answer.withLock { $0 = ok }
            done.signal()
        }
        task.resume()
        guard done.wait(timeout: .now() + seconds + 1) == .success else {
            task.cancel()
            return false
        }
        return answer.withLock { $0 }
    }
}
