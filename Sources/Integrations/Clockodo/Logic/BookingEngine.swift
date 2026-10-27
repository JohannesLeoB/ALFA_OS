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

enum BookingFailure: Error, Equatable, Sendable {
    case unknownCostCenter(String)
    case costCenterWithoutServiceID(String)
    case projectNotFound(String)
    case projectWithoutCustomer(String)
    case customerNotFound(String)
    case customerWithoutClockodoID(String)

    var key: String {
        switch self {
        case .unknownCostCenter: "clockodo.booking.unknownCostCenter"
        case .costCenterWithoutServiceID: "clockodo.booking.costCenterWithoutServiceID"
        case .projectNotFound: "clockodo.booking.projectNotFound"
        case .projectWithoutCustomer: "clockodo.booking.projectWithoutCustomer"
        case .customerNotFound: "clockodo.booking.customerNotFound"
        case .customerWithoutClockodoID: "clockodo.booking.customerWithoutClockodoID"
        }
    }

    var argument: String {
        switch self {
        case .unknownCostCenter(let value), .costCenterWithoutServiceID(let value), .projectNotFound(let value),
             .projectWithoutCustomer(let value), .customerNotFound(let value), .customerWithoutClockodoID(let value):
            value
        }
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
