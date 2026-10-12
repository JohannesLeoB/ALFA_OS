import Foundation

public protocol NumberAuthority: Sendable {
    func nextProjektnummer(jahr: Int) async throws -> Projektnummer

    func reserve(_ number: Projektnummer) async throws

    func isVergeben(_ number: Projektnummer) async throws -> Bool

    func bindFromExternal(source: String, number: Projektnummer) async throws
}

public enum NumberAuthorityMode: String, Codable, Sendable, CaseIterable {
    case local
    case airtable
    case sevdesk
}

public enum NumberAuthorityError: Error, Sendable, Equatable {
    case bereitsVergeben(Projektnummer)
    case unsupported(NumberAuthorityMode)

    case keineKollisionsfreieNummerGefunden(jahr: Int, versuche: Int)
}
