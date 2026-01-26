import XCTest
@testable import Shared

private final class CollectingCueSink: CueSink {
    struct Emitted: Equatable {
        let kind: CueEventKind
        let at: TimeInterval
        let attrs: [String: String]
    }
    var events: [Emitted] = []
    func emit(_ event: CueEventRecord) {
        events.append(.init(kind: event.kind!, at: event.occurredAt.timeIntervalSince1970, attrs: event.attributes))
    }
}

final class WorkoutSessionEngineCueTests: XCTestCase {
    func test_emits_segmentStart_and_transitions_and_last3s_and_completed() throws {
        // Plan: 2 sets, work=5, rest=3 => timeline: w1(0-5), r1(5-8), w2(8-13)
        let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 3, name: "CuePlan")
        let cues = CollectingCueSink()
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), cues: cues)

        // Start tick at t=0 should enter work#1 => segmentStart(work#1)
        XCTAssertEqual(engine.session.status, .running)
        // Already ticked once in start(); no cue collected until we tick again to t=0 exactly.
        _ = engine.tick(at: Date(timeIntervalSince1970: 0))
        // last3s for work#1 at remaining==3 -> duration 5, so at elapsed=2 (t=2)
        _ = engine.tick(at: Date(timeIntervalSince1970: 2))
        // boundary work->rest at t=5
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))
        // last3s for rest#1 at duration 3 => remaining==3 fires at entry, ensure dedup with set marker
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))
        // rest->work at t=8
        _ = engine.tick(at: Date(timeIntervalSince1970: 8))
        // last3s for work#2 at t=10
        _ = engine.tick(at: Date(timeIntervalSince1970: 10))
        // completion at t=13
        _ = engine.tick(at: Date(timeIntervalSince1970: 13))

        // Collect kinds sequence for assertion
        let kinds = cues.events.map { $0.kind }
        // Expect at least these in order (allow duplicates if initial tick produced segmentStart at t=0)
        // - segmentStart(work#1)
        // - last3s(work#1)
        // - workToRest + segmentStart(rest#1)
        // - last3s(rest#1)
        // - restToWork + segmentStart(work#2)
        // - last3s(work#2)
        // - completed
        // We check subsequence order rather than exact counts to keep test resilient.
        func containsSubsequence(_ subseq: [CueEventKind]) -> Bool {
            var idx = 0
            for k in kinds {
                if k == subseq[idx] { idx += 1; if idx == subseq.count { return true } }
            }
            return false
        }

        XCTAssertTrue(
            containsSubsequence([
                .segmentStart,
                .last3s,
                .segmentStart, .workToRest,
                .last3s,
                .segmentStart, .restToWork,
                .last3s,
                .completed
            ]),
            "Cue kinds order did not contain expected subsequence: \(kinds)"
        )
    }

    func test_emits_paused_and_resumed_cues() throws {
        let plan = Plan(setsCount: 1, workSeconds: 6, restSeconds: 0, name: "PausePlan")
        let cues = CollectingCueSink()
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), cues: cues)

        try engine.pause(reason: .user, at: Date(timeIntervalSince1970: 1))
        try engine.resume(at: Date(timeIntervalSince1970: 2))

        let kinds = cues.events.map { $0.kind }
        XCTAssertTrue(kinds.contains(.paused))
        XCTAssertTrue(kinds.contains(.resumed))
    }
}
