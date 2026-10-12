import Foundation

public struct ApprovalProof: Sendable, Equatable, Codable {
    public let proofID: UUID

    public let approvedByUserID: String
    public let verifiedEmail: String

    public let packageID: UUID
    public let revision: Int
    public let payloadSHA256: String
    public let approvedAt: Date
    public let expiresAt: Date

    public let nonce: String

    public init(
        proofID: UUID = UUID(),
        approvedByUserID: String,
        verifiedEmail: String,
        packageID: UUID,
        revision: Int,
        payloadSHA256: String,
        approvedAt: Date,
        expiresAt: Date,
        nonce: String = UUID().uuidString
    ) {
        self.proofID = proofID
        self.approvedByUserID = approvedByUserID
        self.verifiedEmail = verifiedEmail
        self.packageID = packageID
        self.revision = revision
        self.payloadSHA256 = payloadSHA256
        self.approvedAt = approvedAt
        self.expiresAt = expiresAt
        self.nonce = nonce
    }

    public func istAbgelaufen(now: Date = Date()) -> Bool {
        now > expiresAt
    }

    public func passtZu(package: CommercialDraftPackage) -> Bool {
        packageID == package.packageID && revision == package.revision && payloadSHA256 == package.payloadSHA256
    }
}

public enum ApprovalProofCoding {
    public static func encode(_ proof: ApprovalProof) throws -> String {
        let data = try JSONEncoder().encode(proof)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decode(_ raw: String) throws -> ApprovalProof {
        try JSONDecoder().decode(ApprovalProof.self, from: Data(raw.utf8))
    }
}
