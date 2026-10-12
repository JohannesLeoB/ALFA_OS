import Foundation
import GRDB
import Hub
import XCTest

final class AdapterCostTests: XCTestCase {
    private func date(_ day: Int, hour: Int = 12) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day * 86_400 + hour * 3_600))
    }

    func testSumsPerDayAndInlet() throws {
        let cost = try CountingCost(try HubDatabase.inMemory())
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1, bytes: 10), at: date(100, hour: 1)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 2, bytes: 5, tokens: 3), at: date(100, hour: 23)))
        cost.book(CostItem(inlet: "a", capability: .calendar, cost: Cost(calls: 4), at: date(100)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 8), at: date(101)))
        cost.book(CostItem(inlet: "b", capability: .mail, cost: Cost(calls: 16), at: date(100)))
        let dayOne = Period(from: date(100, hour: 0), to: date(100, hour: 23))
        XCTAssertEqual(cost.sum("a", dayOne), Cost(calls: 7, bytes: 15, tokens: 3))
        XCTAssertEqual(cost.sum("a", Period(from: date(101, hour: 0), to: date(101, hour: 23))), Cost(calls: 8))
        XCTAssertEqual(cost.sum("a", .all), Cost(calls: 15, bytes: 15, tokens: 3))
        XCTAssertEqual(cost.sum("b", .all), Cost(calls: 16))
        XCTAssertEqual(cost.sum("none", .all), .zero)
    }

    func testRowsAreKeptPerInletCapabilityAndDay() throws {
        let database = try HubDatabase.inMemory()
        let cost = try CountingCost(database)
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(5)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(5, hour: 3)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(6)))
        cost.book(CostItem(inlet: "a", capability: .files, cost: Cost(calls: 1), at: date(6)))
        let rows = try database.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM cost_day") }
        XCTAssertEqual(rows, 3)
    }

    func testSurvivesReopeningTheSameDatabase() throws {
        let database = try HubDatabase.inMemory()
        try CountingCost(database).book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 2), at: date(7)))
        XCTAssertEqual(try CountingCost(database).sum("a", .all), Cost(calls: 2))
    }
}
