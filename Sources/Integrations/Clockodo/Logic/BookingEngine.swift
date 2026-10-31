import Foundation

enum BookingEngine {
    public struct Project: Equatable, Sendable {
        let number: String
        let customerNumber: String

        init(number: String, customerNumber: String) {
            self.number = number
            self.customerNumber = customerNumber
        }
    }

    public struct Customer: Equatable, Sendable {
        let number: String
        let name: String
        let clockodoID: Int?

        init(number: String, name: String, clockodoID: Int?) {
            self.number = number
            self.name = name
            self.clockodoID = clockodoID
        }
    }

    static func resolve(
        projectNumber: String, costCenter: String, projects: [Project], customers: [Customer],
        costCenters: [CostCenter]
    ) -> Result<BookingTarget, BookingFailure> {
        guard let center = costCenters.first(where: { $0.name == costCenter }) else {
            return .failure(.unknownCostCenter(costCenter))
        }
        guard let activityID = center.clockodoServiceID else {
            return .failure(.costCenterWithoutServiceID(costCenter))
        }
        guard let project = projects.first(where: { $0.number == projectNumber }) else {
            return .failure(.projectNotFound(projectNumber))
        }
        let customerNumber = project.customerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard customerNumber.isEmpty == false else {
            return .failure(.projectWithoutCustomer(projectNumber))
        }
        guard let customer = customers.first(where: { $0.number == customerNumber }) else {
            return .failure(.customerNotFound(customerNumber))
        }
        guard let customerID = customer.clockodoID else {
            return .failure(.customerWithoutClockodoID(customer.name))
        }
        return .success(BookingTarget(customerID: customerID, activityID: activityID))
    }
}

struct BookingTarget: Equatable, Sendable {
    let customerID: Int
    let activityID: Int

    init(customerID: Int, activityID: Int) {
        self.customerID = customerID
        self.activityID = activityID
    }
}

struct CostCenter: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let clockodoServiceID: Int?

    init(id: String? = nil, name: String, clockodoServiceID: Int? = nil) {
        self.id = id ?? name
        self.name = name
        self.clockodoServiceID = clockodoServiceID
    }
}

struct EntryParser: Decodable {
    var id: Int
    var customersID: Int
    var projectsID: Int?
    var servicesID: Int
    var text: String?
    var timeSince: String?
    var duration: Int?
    var billable: Int?

    enum CodingKeys: String, CodingKey {
        case id, text, duration, billable
        case customersID = "customers_id"
        case projectsID = "projects_id"
        case servicesID = "services_id"
        case timeSince = "time_since"
    }

    struct Customer: Decodable {
        var id: Int
        var name: String
        var active: Bool?
    }

    struct Project: Decodable {
        var id: Int
        var name: String
        var active: Bool?
        var customersID: Int

        enum CodingKeys: String, CodingKey {
            case id, name, active
            case customersID = "customers_id"
        }
    }

    struct Activity: Decodable {
        var id: Int
        var name: String
        var active: Bool?
    }

    static func page<T: Decodable>(from data: Data, key: String) throws -> (items: [T], pageCount: Int) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RequestFailure.decoding
        }
        let raw = (root["data"] as? [[String: Any]]) ?? (root[key] as? [[String: Any]]) ?? []
        let pageCount = ((root["paging"] as? [String: Any])?["count_pages"] as? Int) ?? 1
        do {
            let items = try JSONDecoder().decode([T].self, from: JSONSerialization.data(withJSONObject: raw))
            return (items, pageCount)
        } catch {
            throw RequestFailure.decoding
        }
    }

    static func customers(_ items: [Customer]) -> [TimeCustomer] {
        items.map { TimeCustomer(id: $0.id, name: $0.name, isActive: $0.active ?? true) }
    }

    static func projects(_ items: [Project]) -> [TimeProject] {
        items.map { TimeProject(id: $0.id, customerID: $0.customersID, name: $0.name, isActive: $0.active ?? true) }
    }

    static func activities(_ items: [Activity]) -> [TimeActivity] {
        items.map { TimeActivity(id: $0.id, name: $0.name, isActive: $0.active ?? true) }
    }

    static func entries(_ items: [EntryParser]) -> [TimeEntry] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return items.map { item in
            TimeEntry(
                id: item.id, customerID: item.customersID, projectID: item.projectsID, activityID: item.servicesID,
                text: item.text, start: item.timeSince.flatMap { formatter.date(from: $0) } ?? Date(timeIntervalSince1970: 0),
                seconds: item.duration ?? 0, billable: (item.billable ?? 1) >= 1)
        }
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func createBody(
        customerID: Int, activityID: Int, projectID: Int?, since: Date, until: Date, billable: Bool, text: String?
    ) -> Data {
        var payload: [String: Any] = [
            "customers_id": customerID,
            "services_id": activityID,
            "billable": billable ? 1 : 0,
            "time_since": timestamp(since),
            "time_until": timestamp(until),
        ]
        if let projectID { payload["projects_id"] = projectID }
        if let text, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false { payload["text"] = text }
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    static func createdID(from data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = object["entry"] as? [String: Any],
              let id = entry["id"] else { throw RequestFailure.decoding }
        return String(describing: id)
    }
}
