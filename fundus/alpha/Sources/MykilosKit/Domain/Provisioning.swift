import Foundation

public struct ProvisioningPlan: Sendable, Equatable {
    public let projektnummer: Projektnummer
    public let kdnr: String
    public let customerName: String

    public let folderName: String

    public let airtableFelder: [String: String]

    public let schema: FolderSchema

    public init(projektnummer: Projektnummer, kdnr: String, customerName: String,
                folderName: String, airtableFelder: [String: String], schema: FolderSchema) {
        self.projektnummer = projektnummer
        self.kdnr = kdnr
        self.customerName = customerName
        self.folderName = folderName
        self.airtableFelder = airtableFelder
        self.schema = schema
    }

    public var idempotenzSchluessel: String { "\(kdnr)::\(projektnummer.appFormat)" }
}

public enum ProvisioningStep: String, Codable, Sendable, CaseIterable {
    case driveOrdnerbaum
    case airtableRecord

    case clickUpStruktur
}

public enum ProvisioningStatus: String, Codable, Sendable, Equatable {
    case offen
    case teilweise
    case vollstaendig
    case error
}

public struct ProvisioningResult: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case idempotenzSchluessel, projektnummer, kdnr, status, erledigteSchritte, driveProjectFolderId = "driveProjektOrdnerID", driveUnterordnerIDs, airtableRecordID, clickUpListID, lastError = "letzterFehler", updatedAt }

    public var idempotenzSchluessel: String
    public var projektnummer: String
    public var kdnr: String
    public var status: ProvisioningStatus
    public var erledigteSchritte: Set<ProvisioningStep>
    public var driveProjectFolderId: String?
    public var driveUnterordnerIDs: [String: String]
    public var airtableRecordID: String?

    public var clickUpListID: String?
    public var lastError: String?
    public var updatedAt: Date

    public init(
        idempotenzSchluessel: String, projektnummer: String, kdnr: String,
        status: ProvisioningStatus = .offen, erledigteSchritte: Set<ProvisioningStep> = [],
        driveProjectFolderId: String? = nil, driveUnterordnerIDs: [String: String] = [:],
        airtableRecordID: String? = nil, clickUpListID: String? = nil,
        lastError: String? = nil, updatedAt: Date = Date()
    ) {
        self.idempotenzSchluessel = idempotenzSchluessel
        self.projektnummer = projektnummer
        self.kdnr = kdnr
        self.status = status
        self.erledigteSchritte = erledigteSchritte
        self.driveProjectFolderId = driveProjectFolderId
        self.driveUnterordnerIDs = driveUnterordnerIDs
        self.airtableRecordID = airtableRecordID
        self.clickUpListID = clickUpListID
        self.lastError = lastError
        self.updatedAt = updatedAt
    }

    public func hat(_ step: ProvisioningStep) -> Bool { erledigteSchritte.contains(step) }
}

public enum ProvisioningError: Error, Sendable, Equatable {
    case writeGateGesperrt
    case driveNichtVerbunden
    case airtableNichtVerbunden
    case schrittFehlgeschlagen(ProvisioningStep, String)
    case ungueltigerPlan(String)
}
