import XCTest
@testable import Shared

final class WorkoutSessionEngineCountdownTests: XCTestCase {
    private final class CollectingSink: @unchecked Sendable, CueSink {
        var events: [CueEventRecord] = []
        func emit(_ event: CueEventRecord) { events.append(event) }
    }

    func test_emits321CountdownOncePerSecondPerSegment() throws {
        let plan = Plan(setsCount: 1, workSeconds: 5, restSeconds: 0, name: "Countdown")
        let sink = CollectingSink()
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), cues: sink)

        _ = engine.tick(at: Date(timeIntervalSince1970: 2))
        _ = engine.tick(at: Date(timeIntervalSince1970: 3))
        _ = engine.tick(at: Date(timeIntervalSince1970: 4))
        _ = engine.tick(at: Date(timeIntervalSince1970: 4))

        let countdownEvents = sink.events.filter { $0.kind == .last3s }
        let values = countdownEvents.compactMap { $0.attributes["remaining"] }

        XCTAssertEqual(values, ["3", "2", "1"])
    }
}
