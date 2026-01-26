import XCTest
@testable import Shared

final class WorkoutSessionEngineCueCoalescingTests: XCTestCase {
    private final class CollectingSink: CueSink {
        var events: [CueEventRecord] = []
        func emit(_ event: CueEventRecord) { events.append(event) }
    }

    func test_same_second_cues_are_coalesced_and_segmentStart_is_prioritized() throws {
        // Plan: work=5, rest=3 -> boundaries at t=0 (start), t=5 (to rest), t=8 (to work), t=13 (complete)
        let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 3, name: "CoalescePlan")
        let base = Date(timeIntervalSince1970: 0)
        let collector = CollectingSink()
        let sink = CueCoalescingSink(collector)
        var engine = try WorkoutSessionEngine(plan: plan, now: base, cues: sink)

        // Drive to boundary where multiple cues may occur in the same second.
        _ = engine.tick(at: Date(timeIntervalSince1970: 0))   // initial entry into work
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))   // work -> rest (segmentStart + workToRest [+ last3s(rest)])
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))   // tick again same second to simulate re-entry last3s-at-entry scenario

        // Filter events that occurred at second 5
        let sameSec = collector.events.filter { Int($0.occurredAt.timeIntervalSince1970) == 5 }
        XCTAssertEqual(sameSec.count, 1, "Only one cue should pass within the same second (coalesced)")
        XCTAssertEqual(sameSec.first?.kind, .segmentStart, "SegmentStart should be prioritized at the boundary")

        // Next boundary should allow emission again (new second)
        _ = engine.tick(at: Date(timeIntervalSince1970: 8))   // rest -> work
        let sec8 = collector.events.filter { Int($0.occurredAt.timeIntervalSince1970) == 8 }
        XCTAssertEqual(sec8.count, 1, "New second should emit again after coalescing")
        XCTAssertEqual(sec8.first?.kind, .segmentStart)

        // Non-boundary single cue still flows
        _ = engine.tick(at: Date(timeIntervalSince1970: 10))  // last3s(work#2)
        let sec10 = collector.events.filter { Int($0.occurredAt.timeIntervalSince1970) == 10 }
        XCTAssertEqual(sec10.count, 1)
        XCTAssertEqual(sec10.first?.kind, .last3s)

        _ = engine.tick(at: Date(timeIntervalSince1970: 13))  // completed
        let sec13 = collector.events.filter { Int($0.occurredAt.timeIntervalSince1970) == 13 }
        XCTAssertEqual(sec13.count, 1)
        XCTAssertEqual(sec13.first?.kind, .completed)
    }
}