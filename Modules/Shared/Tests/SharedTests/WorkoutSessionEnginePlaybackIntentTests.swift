import XCTest
@testable import Shared

private final class CollectingPlaybackIntentSink: @unchecked Sendable, PlaybackIntentSink {
    var intents: [PlaybackIntent] = []
    func emit(_ intent: PlaybackIntent) { intents.append(intent) }
}

final class WorkoutSessionEnginePlaybackIntentTests: XCTestCase {
    func test_emitsSegmentChangedIntents() throws {
        // Plan: 2 sets, work=5, rest=3 => w1(0-5), r1(5-8), w2(8-13)
        let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 3, name: "PlaybackPlan")
        let sink = CollectingPlaybackIntentSink()
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), playback: sink)

        _ = engine.tick(at: Date(timeIntervalSince1970: 0))
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))
        _ = engine.tick(at: Date(timeIntervalSince1970: 8))

        let toIds: [String] = sink.intents.compactMap {
            guard case let .segmentChanged(_, _, to, _, _) = $0 else { return nil }
            return to
        }
        XCTAssertTrue(toIds.contains("work#1"), "Expected intent for work#1; got \(toIds)")
        XCTAssertTrue(toIds.contains("rest#1"), "Expected intent for rest#1; got \(toIds)")
        XCTAssertTrue(toIds.contains("work#2"), "Expected intent for work#2; got \(toIds)")
    }
}
