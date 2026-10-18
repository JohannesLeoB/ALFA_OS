import Foundation
import GRDB

public struct AufmassEntwurfRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, erstelltAm, projectNumber = "projektNummer", title = "titel", dokumentJSON, fotoPNG, imageExtension = "bildEndung" }

    public static var databaseTableName: String { "aufmassEntwurf" }

    public var id: String
    public var erstelltAm: Double
    public var projectNumber: String?
    public var title: String
    public var dokumentJSON: String
    public var fotoPNG: Data?
    public var imageExtension: String?

    public init(id: String, erstelltAm: Double, projectNumber: String?, title: String,
                dokumentJSON: String, fotoPNG: Data?, imageExtension: String?) {
        self.id = id
        self.erstelltAm = erstelltAm
        self.projectNumber = projectNumber
        self.title = title
        self.dokumentJSON = dokumentJSON
        self.fotoPNG = fotoPNG
        self.imageExtension = imageExtension
    }
}
