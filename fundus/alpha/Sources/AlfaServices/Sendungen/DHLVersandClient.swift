import Foundation
import AlfaKit

public struct VersandLabelErgebnis: Sendable, Equatable {
    public let trackingNummer: String

    public let labelBase64: String?
    public let statusText: String?

    public init(trackingNummer: String, labelBase64: String?, statusText: String?) {
        self.trackingNummer = trackingNummer
        self.labelBase64 = labelBase64
        self.statusText = statusText
    }
}

public enum DHLVersandFehler: Error, Equatable {
    case keineZugangsdaten

    case unvollstaendig([DHLAuftragFehler])
    case netz(String)
    case parse(String)
}

extension DHLVersandFehler: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .keineZugangsdaten:
            return "Keine vollständigen DHL-Versand-Zugangsdaten hinterlegt — API-Key, "
                 + "API-Secret, Benutzer und Passwort in den Einstellungen → Integrationen → "
                 + "DHL Versand eintragen."
        case .unvollstaendig(let error):
            return "Sendung unvollständig: " + error.map(\.rawValue).joined(separator: " · ")
        case .netz(let ground):
            return "DHL antwortet nicht wie erwartet: \(ground)"
        case .parse(let ground):
            return "Die Antwort von DHL war nicht lesbar: \(ground)"
        }
    }
}

public protocol SendungErstellend: Sendable {
    func erstelleLabel(_ auftrag: DHLVersandAuftrag) async throws -> VersandLabelErgebnis
}

public struct DHLVersandClient: SendungErstellend {
    private let apiKey: String?
    private let apiSecret: String?
    private let benutzer: String?
    private let passwort: String?
    private let session: URLSession

    public init(apiKey: String? = nil, apiSecret: String? = nil, benutzer: String? = nil, passwort: String? = nil,
                session: URLSession = .shared) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.benutzer = benutzer
        self.passwort = passwort
        self.session = session
    }

    public static func ausSchluesselbund(
        store: any DHLVersandCredentialsStoring = KeychainDHLVersandCredentialsStore(),
        session: URLSession = .shared
    ) -> DHLVersandClient {
        let creds = try? store.load()
        return DHLVersandClient(
            apiKey: creds?.apiKey, apiSecret: creds?.apiSecret, benutzer: creds?.benutzer, passwort: creds?.passwort,
            session: session)
    }

    private static let endpoint = "https://api-eu.dhl.com/parcel/de/shipping/v2/orders"
    private static let tokenEndpoint = "https://api-eu.dhl.com/parcel/de/account/auth/ropc/v1/token"

    public var istAngeschlossen: Bool {
        (apiKey?.isEmpty == false) && (apiSecret?.isEmpty == false)
        && (benutzer?.isEmpty == false) && (passwort?.isEmpty == false)
    }

    public func erstelleLabel(_ auftrag: DHLVersandAuftrag) async throws -> VersandLabelErgebnis {
        let error = DHLAuftragPruefung.pruefe(auftrag)
        guard error.isEmpty else { throw DHLVersandFehler.unvollstaendig(error) }

        guard let apiKey, apiKey.isEmpty == false,
              let apiSecret, apiSecret.isEmpty == false,
              let benutzer, benutzer.isEmpty == false,
              let passwort, passwort.isEmpty == false else {
            throw DHLVersandFehler.keineZugangsdaten
        }

        let token = try await holeToken(apiKey: apiKey, apiSecret: apiSecret, benutzer: benutzer, passwort: passwort)

        var req = URLRequest(url: URL(string: Self.endpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(DHLOrderBuilder.request(auftrag))

        let data: Data
        do {
            let (d, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) == false {
                throw DHLVersandFehler.netz("HTTP \(http.statusCode): \(String(data: d, encoding: .utf8) ?? "")")
            }
            data = d
        } catch let e as DHLVersandFehler {
            throw e
        } catch {
            throw DHLVersandFehler.netz(String(describing: error))
        }

        return try Self.parse(data)
    }

    private func holeToken(apiKey: String, apiSecret: String, benutzer: String, passwort: String) async throws -> String {
        var req = URLRequest(url: URL(string: Self.tokenEndpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.buildTokenRequestBody(
            clientID: apiKey, clientSecret: apiSecret, benutzer: benutzer, passwort: passwort)

        let data: Data
        do {
            let (d, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) == false {
                throw DHLVersandFehler.netz("Token-Anfrage: HTTP \(http.statusCode)")
            }
            data = d
        } catch let e as DHLVersandFehler {
            throw e
        } catch {
            throw DHLVersandFehler.netz("Token-Anfrage: \(String(describing: error))")
        }
        return try Self.parseTokenResponse(from: data)
    }

    public static func buildTokenRequestBody(clientID: String, clientSecret: String, benutzer: String, passwort: String) -> Data {
        let felder = [
            ("grant_type", "password"),
            ("client_id", clientID),
            ("client_secret", clientSecret),
            ("username", benutzer),
            ("password", passwort)
        ]
        let text = felder.map { "\($0.0)=\(formUrlEncode($0.1))" }.joined(separator: "&")
        return Data(text.utf8)
    }

    private static func formUrlEncode(_ value: String) -> String {
        var erlaubt = CharacterSet.alphanumerics
        erlaubt.insert(charactersIn: "-._~")
        let encoded = value.addingPercentEncoding(withAllowedCharacters: erlaubt) ?? value
        return encoded.replacingOccurrences(of: " ", with: "+")
    }

    public static func parseTokenResponse(from data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = root["access_token"] as? String, token.isEmpty == false else {
            throw DHLVersandFehler.parse("Kein access_token in der Token-Antwort.")
        }
        return token
    }

    public static func parse(_ data: Data) throws -> VersandLabelErgebnis {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]],
              let erste = items.first,
              let tracking = erste["shipmentNo"] as? String else {
            throw DHLVersandFehler.parse("Keine Sendungsnummer in der Antwort.")
        }
        let label = (erste["label"] as? [String: Any])?["b64"] as? String
        let status = (erste["sstatus"] as? [String: Any])?["title"] as? String
        return VersandLabelErgebnis(trackingNummer: tracking, labelBase64: label, statusText: status)
    }
}
