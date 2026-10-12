import Foundation
import GRDB
import Hub
import struct MykilosServices.IMAPSMTPMailTransport
import protocol MykilosServices.MailTransport
import XCTest

final class Repro3AdapterTests: XCTestCase {
    func testBug20CostSumIncludesTheWholeUTCDayOfBothPeriodEnds() throws {
        let cost = try CountingCost(try HubDatabase.inMemory())
        let midnight = Date(timeIntervalSince1970: TimeInterval(20_000 * 86_400))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: midnight.addingTimeInterval(3_600)))
        let hour = Period(from: midnight.addingTimeInterval(12 * 3_600), to: midnight.addingTimeInterval(13 * 3_600))
        let calls = cost.sum("a", hour).calls
        XCTExpectFailure("BUG-3-20: sum() truncates both period ends to UTC days; a booking at 01:00 counts for the period 12:00 to 13:00") {
            XCTAssertEqual(calls, 0)
        }
    }

    func testBug21EveryZeroRunsTheSyncInATightLoop() async throws {
        let cadence = TimerCadence()
        let runs = Locked(0)
        cadence.attach { inlet, capability in
            runs.with { $0 += 1 }
            return SyncReport(inlet: inlet, capability: capability, result: .skipped)
        }
        cadence.plan("i1", .mail, .every(.zero))
        try await Task.sleep(for: .milliseconds(150))
        cadence.plan("i1", .mail, .off)
        let count = runs.with { $0 }
        XCTExpectFailure("BUG-3-21: setCadence accepts any Duration; a zero or negative interval has no lower bound (assumption: a minimum exists)") {
            XCTAssertLessThan(count, 5)
        }
    }
}
