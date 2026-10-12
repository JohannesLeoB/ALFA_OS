import Foundation
import Hub
import XCTest

private actor Ticker {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private(set) var requested: [Duration] = []

    var waiters: Int { waiting.count }

    func sleep(_ duration: Duration) async {
        requested.append(duration)
        await withCheckedContinuation { waiting.append($0) }
    }

    func tick() {
        let current = waiting
        waiting = []
        current.forEach { $0.resume() }
    }
}

private actor Counter {
    private(set) var calls = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var blocking = false

    func block() { blocking = true }

    func run() async {
        calls += 1
        guard blocking else { return }
        blocking = false
        await withCheckedContinuation { gate = $0 }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

final class AdapterTimerTests: XCTestCase {
    private func until(_ condition: @Sendable () async -> Bool) async -> Bool {
        for _ in 0..<400 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return await condition()
    }

    func testIntervalTriggersExactlyOnceAfterTheTick() async throws {
        let ticker = Ticker()
        let counter = Counter()
        let cadence = TimerCadence(sleep: { await ticker.sleep($0) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .finished(items: 0))
        }
        cadence.plan("i1", .mail, .every(.seconds(300)))
        let armed = await until { await ticker.waiters == 1 }
        XCTAssertTrue(armed)
        let requested = await ticker.requested
        XCTAssertEqual(requested, [.seconds(300)])
        let before = await counter.calls
        XCTAssertEqual(before, 0)
        await ticker.tick()
        let fired = await until { await counter.calls == 1 }
        XCTAssertTrue(fired)
        let rearmed = await until { await ticker.waiters == 1 }
        XCTAssertTrue(rearmed)
        try await Task.sleep(for: .milliseconds(30))
        let after = await counter.calls
        XCTAssertEqual(after, 1)
        cadence.plan("i1", .mail, .off)
    }

    func testSecondTriggerDuringARunIsSkipped() async throws {
        let counter = Counter()
        await counter.block()
        let cadence = TimerCadence(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .finished(items: 0))
        }
        let first = Task { await cadence.trigger("i1", .mail) }
        let started = await until { await counter.calls == 1 }
        XCTAssertTrue(started)
        await cadence.trigger("i1", .mail)
        let during = await counter.calls
        XCTAssertEqual(during, 1)
        await cadence.trigger("i2", .mail)
        let other = await until { await counter.calls == 2 }
        XCTAssertTrue(other)
        await counter.release()
        await first.value
        await cadence.trigger("i1", .mail)
        let again = await counter.calls
        XCTAssertEqual(again, 3)
    }

    func testReplanningWithOffStopsTheTimer() async throws {
        let ticker = Ticker()
        let counter = Counter()
        let cadence = TimerCadence(sleep: { await ticker.sleep($0) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .skipped)
        }
        cadence.plan("i1", .mail, .every(.seconds(10)))
        _ = await until { await ticker.waiters == 1 }
        cadence.plan("i1", .mail, .manual)
        await ticker.tick()
        try await Task.sleep(for: .milliseconds(30))
        let calls = await counter.calls
        XCTAssertEqual(calls, 0)
    }
}
