import Foundation

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
