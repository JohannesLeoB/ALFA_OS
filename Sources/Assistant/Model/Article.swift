import Foundation

public struct Article: Sendable, Equatable {
    public let id: String
    public let articleNumber: String
    public let manufacturer: String?
    public let summary: String?
    public let purchaseNet: Double?
    public let saleNet: Double?

    public init(id: String, articleNumber: String, manufacturer: String? = nil, summary: String? = nil,
                purchaseNet: Double? = nil, saleNet: Double? = nil) {
        self.id = id
        self.articleNumber = articleNumber
        self.manufacturer = manufacturer
        self.summary = summary
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
    }

    public var label: String { summary ?? articleNumber }
}

public struct StockItem: Sendable, Equatable {
    public let id: String
    public let label: String
    public let manufacturer: String?
    public let category: String?
    public let articleNumber: String?
    public let quantity: Int?
    public let purchaseNet: Double?
    public let saleNet: Double?

    public init(id: String, label: String, manufacturer: String? = nil, category: String? = nil,
                articleNumber: String? = nil, quantity: Int? = nil, purchaseNet: Double? = nil, saleNet: Double? = nil) {
        self.id = id
        self.label = label
        self.manufacturer = manufacturer
        self.category = category
        self.articleNumber = articleNumber
        self.quantity = quantity
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
    }
}

struct SampleListing: Sendable, Equatable {
    struct Sample: Sendable, Equatable {
        let label: String
        let manufacturer: String?
        let category: String?
        let statusLabel: String

        init(label: String, manufacturer: String? = nil, category: String? = nil, statusLabel: String) {
            self.label = label
            self.manufacturer = manufacturer
            self.category = category
            self.statusLabel = statusLabel
        }
    }

    let samples: [Sample]
    let defective: Int

    init(samples: [Sample], defective: Int = 0) {
        self.samples = samples
        self.defective = defective
    }
}

public struct ShipmentStatus: Sendable, Equatable {
    public let number: String
    public let statusLabel: String
    public let detail: String?

    public init(number: String, statusLabel: String, detail: String? = nil) {
        self.number = number
        self.statusLabel = statusLabel
        self.detail = detail
    }
}

public struct ReceiptEntry: Sendable, Equatable {
    public let kind: String
    public let number: String
    public let projectNumber: String
    public let customerName: String?
    public let createdAt: Date

    public init(kind: String, number: String, projectNumber: String, customerName: String? = nil, createdAt: Date) {
        self.kind = kind
        self.number = number
        self.projectNumber = projectNumber
        self.customerName = customerName
        self.createdAt = createdAt
    }
}

public struct TimeReport: Sendable, Equatable {
    public struct Entry: Sendable, Equatable {
        public let start: Date
        public let customer: String
        public let service: String
        public let seconds: Int
        public let note: String?

        public init(start: Date, customer: String, service: String, seconds: Int, note: String? = nil) {
            self.start = start
            self.customer = customer
            self.service = service
            self.seconds = seconds
            self.note = note
        }
    }

    public let entries: [Entry]
    public let error: String?

    public init(entries: [Entry], error: String? = nil) {
        self.entries = entries
        self.error = error
    }
}

public enum TimePeriod: String, Sendable, Equatable, CaseIterable {
    case today = "heute"
    case week = "woche"
    case month = "monat"
}

public struct TaskItem: Sendable, Equatable {
    public let id: String
    public let name: String
    public let status: String
    public let isUrgent: Bool
    public let dueDate: Date?
    public let assignee: String?

    public init(id: String, name: String, status: String, isUrgent: Bool = false, dueDate: Date? = nil,
                assignee: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.isUrgent = isUrgent
        self.dueDate = dueDate
        self.assignee = assignee
    }
}

public struct TaskMember: Sendable, Equatable {
    public let id: String
    public let username: String

    public init(id: String, username: String) {
        self.id = id
        self.username = username
    }
}

public struct ProjectTaskList: Sendable, Equatable {
    let projectNumber: String
    let title: String
    let listID: String

    init(projectNumber: String, title: String, listID: String) {
        self.projectNumber = projectNumber
        self.title = title
        self.listID = listID
    }
}
