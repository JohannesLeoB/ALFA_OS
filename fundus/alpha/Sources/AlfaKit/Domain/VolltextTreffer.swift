import Foundation

public struct VolltextTreffer: Identifiable, Sendable, Equatable {
    public enum AreaEntry: String, Sendable, CaseIterable {
        case sampling
        case service
        case termine
        case telefonnotiz

        public var tabName: String {
            switch self {
            case .sampling:  return "Bemusterung"
            case .service:      return "Service"
            case .termine:      return "Termine"
            case .telefonnotiz: return "Timeline"
            }
        }
        public var label: String {
            switch self {
            case .sampling:  return "Bemusterung"
            case .service:      return "Service"
            case .termine:      return "Termin"
            case .telefonnotiz: return "Telefonnotiz"
            }
        }
        public var icon: String {
            switch self {
            case .sampling:  return "swatchpalette"
            case .service:      return "wrench.and.screwdriver"
            case .termine:      return "flag.checkered"
            case .telefonnotiz: return "phone"
            }
        }
    }

    public let id: String
    public let projectNumber: String
    public let area: AreaEntry
    public let title: String
    public let schnipsel: String

    public init(id: String, projectNumber: String, area: AreaEntry, title: String, schnipsel: String) {
        self.id = id
        self.projectNumber = projectNumber
        self.area = area
        self.title = title
        self.schnipsel = schnipsel
    }
}
