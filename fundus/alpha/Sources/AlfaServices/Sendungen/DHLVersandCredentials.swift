import Foundation
import AlfaKit

public struct DHLVersandCredentials: Equatable, Sendable {
    public var apiKey: String
    public var apiSecret: String
    public var benutzer: String
    public var passwort: String
    public var abrechnungsnummer: String
    public var sandbox: Bool
    public var absender: DHLAdresse?

    public init(
        apiKey: String, apiSecret: String, benutzer: String, passwort: String, abrechnungsnummer: String,
        sandbox: Bool, absender: DHLAdresse? = nil
    ) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.benutzer = benutzer
        self.passwort = passwort
        self.abrechnungsnummer = abrechnungsnummer
        self.sandbox = sandbox
        self.absender = absender
    }
}

public protocol DHLVersandCredentialsStoring: Sendable {
    func store(_ credentials: DHLVersandCredentials) throws
    func load() throws -> DHLVersandCredentials?
    func clear() throws
}

public struct KeychainDHLVersandCredentialsStore: DHLVersandCredentialsStoring {
    private static let apiKeyAccount = "apiKey"
    private static let apiSecretAccount = "apiSecret"
    private static let benutzerAccount = "benutzer"
    private static let passwortAccount = "passwort"
    private static let abrechnungsnummerAccount = "abrechnungsnummer"
    private static let sandboxAccount = "sandbox"
    private static let absenderAccount = "absenderJSON"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(
            .dhlShipping,
            fields: [
                CredentialField(Self.apiKeyAccount), CredentialField(Self.apiSecretAccount),
                CredentialField(Self.benutzerAccount), CredentialField(Self.passwortAccount),
                CredentialField(Self.abrechnungsnummerAccount),
                CredentialField(Self.sandboxAccount),
                CredentialField(Self.absenderAccount, isRequired: false)
            ],
            keychain: keychain, userID: userID)
    }

    public func store(_ credentials: DHLVersandCredentials) throws {
        var values: [String: String] = [
            Self.apiKeyAccount: credentials.apiKey,
            Self.apiSecretAccount: credentials.apiSecret,
            Self.benutzerAccount: credentials.benutzer,
            Self.passwortAccount: credentials.passwort,
            Self.abrechnungsnummerAccount: credentials.abrechnungsnummer,
            Self.sandboxAccount: credentials.sandbox ? "1" : "0"
        ]
        if let absender = credentials.absender {
            if let json = try? JSONEncoder().encode(absender), let jsonString = String(data: json, encoding: .utf8) {
                values[Self.absenderAccount] = jsonString
            }
        }
        try vault.store(values)
    }

    public func load() throws -> DHLVersandCredentials? {
        guard let values = try vault.load(),
              let apiKey = values[Self.apiKeyAccount], let apiSecret = values[Self.apiSecretAccount],
              let benutzer = values[Self.benutzerAccount], let passwort = values[Self.passwortAccount],
              let abrechnungsnummer = values[Self.abrechnungsnummerAccount],
              let sandboxWert = values[Self.sandboxAccount]
        else { return nil }

        let absender: DHLAdresse? = values[Self.absenderAccount]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(DHLAdresse.self, from: $0) }

        return DHLVersandCredentials(
            apiKey: apiKey, apiSecret: apiSecret, benutzer: benutzer, passwort: passwort,
            abrechnungsnummer: abrechnungsnummer, sandbox: sandboxWert != "0", absender: absender)
    }

    public func clear() throws {
        try vault.clear()
    }
}
