import Foundation
import MykilosKit

public protocol SendungsVerfolgend: Sendable {
    func verfolge(_ sendung: Sendung) async throws -> Sendung
}

public enum SendungsFehler: Error, Equatable {
    case keinApiKey

    case nichtUnterstuetzt

    case keyAbgelehnt(Int)
    case netz(String)
    case parse(String)
}

extension SendungsFehler: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .keinApiKey:
            return "Kein DHL-API-Key hinterlegt — in den Einstellungen eintragen."
        case .nichtUnterstuetzt:
            return "Für diesen Versanddienst gibt es keinen Abruf — DHL wird unterstützt, "
                 + "Hermes hat keinen offenen Zugang."
        case .keyAbgelehnt(let status):
            return "DHL lehnt den Key ab (HTTP \(status)). Bei einem frisch erstellten Key ist "
                 + "das normal: DHL schaltet ihn laut eigenem Portal-Hinweis erst nach bis zu "
                 + "24 Stunden frei. Bleibt es danach dabei, den Key in den Einstellungen prüfen."
        case .netz(let ground):
            return "DHL antwortet nicht wie erwartet: \(ground)"
        case .parse(let ground):
            return "Die Antwort von DHL war nicht lesbar: \(ground)"
        }
    }
}

public struct DHLSendungsClient: SendungsVerfolgend {
    private let apiKey: String?
    private let session: URLSession
    private static let endpoint = "https://api-eu.dhl.com/track/shipments"

    public init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public static func ausSchluesselbund(
        store: any DHLCredentialsStoring = KeychainDHLCredentialsStore(),
        versandStore: any DHLVersandCredentialsStoring = KeychainDHLVersandCredentialsStore(),
        session: URLSession = .shared
    ) -> DHLSendungsClient {
        let trackingKey = (try? store.load()?.apiKey).flatMap { $0.isEmpty ? nil : $0 }
        let key = trackingKey ?? (try? versandStore.load()?.apiKey).flatMap { $0.isEmpty ? nil : $0 }
        return DHLSendungsClient(apiKey: key, session: session)
    }

    public var istAngeschlossen: Bool { (apiKey?.isEmpty == false) }

    public func verfolge(_ sendung: Sendung) async throws -> Sendung {
        guard sendung.dienst == .dhl else { throw SendungsFehler.nichtUnterstuetzt }
        guard let apiKey, apiKey.isEmpty == false else { throw SendungsFehler.keinApiKey }

        var comps = URLComponents(string: Self.endpoint)!
        comps.queryItems = [
            URLQueryItem(name: "trackingNumber", value: sendung.trackingNummer),
            URLQueryItem(name: "language", value: "de")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(apiKey, forHTTPHeaderField: "DHL-API-Key")

        let data: Data
        do {
            let (d, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) == false {
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw SendungsFehler.keyAbgelehnt(http.statusCode)
                }
                throw SendungsFehler.netz("HTTP \(http.statusCode)")
            }
            data = d
        } catch let error as SendungsFehler {
            throw error
        } catch {
            throw SendungsFehler.netz(String(describing: error))
        }

        let roh = try Self.parse(data)
        var aktualisiert = sendung
        aktualisiert.status = DHLStatusMapping.status(ausCode: roh.statusCode, text: roh.statusText)
        aktualisiert.statusText = roh.etaText ?? roh.statusText
        return aktualisiert
    }

    public struct RohStatus: Equatable {
        public let statusCode: String
        public let statusText: String?
        public let etaText: String?
    }

    public static func parse(_ data: Data) throws -> RohStatus {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shipments = root["shipments"] as? [[String: Any]],
              let erste = shipments.first else {
            throw SendungsFehler.parse("Keine Sendung in der Antwort.")
        }
        let status = erste["status"] as? [String: Any]
        let code = (status?["statusCode"] as? String) ?? "unknown"
        let text = status?["status"] as? String
        let eta = erste["estimatedTimeOfDelivery"] as? String
        return RohStatus(statusCode: code, statusText: text, etaText: eta)
    }
}
