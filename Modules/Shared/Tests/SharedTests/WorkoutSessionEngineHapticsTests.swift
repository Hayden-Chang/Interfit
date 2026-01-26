import XCTest
@testable import Shared

final class WorkoutSessionEngineHapticsTests: XCTestCase {
    func test_engine_emits_haptic_patterns_for_key_events() throws {
        // Plan: 2 sets, work=5, rest=3 => timeline: w1(0-5), r1(5-8), w2(8-13)
        let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 3, name: "HapticsPlan")
        var captured: [HapticPattern] = []
        let sink = HapticsCueSink(enabled: true) { patterns in
            captured.append(contentsOf: patterns)
        }
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), cues: sink)

        // Drive ticks similar to cue tests
        _ = engine.tick(at: Date(timeIntervalSince1970: 0))   // enter work#1 -> rigid
        _ = engine.tick(at: Date(timeIntervalSince1970: 2))   // last3s(work#1) -> light
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))   // work->rest -> warning + soft
        _ = engine.tick(at: Date(timeIntervalSince1970: 5))   // last3s(rest#1) -> light (fires at entry)
        _ = engine.tick(at: Date(timeIntervalSince1970: 8))   // rest->work -> success + rigid
        _ = engine.tick(at: Date(timeIntervalSince1970: 10))  // last3s(work#2) -> light
        _ = engine.tick(at: Date(timeIntervalSince1970: 13))  // completed -> success

        // We don't assert exact counts; ensure key patterns appear in reasonable order.
        func containsSubsequence(_ subseq: [HapticPattern]) -> Bool {
            var idx = 0
            for k in captured {
                if k == subseq[idx] { idx += 1; if idx == subseq.count { return true } }
            }
            return false
        }

        XCTAssertTrue(
            containsSubsequence([
                .impactRigid,         // enter work#1
                .impactLight,         // last3s
                .impactSoft,          // segmentStart(rest)
                .notificationWarning, // work->rest
                .impactLight,         // last3s(rest)
                .impactRigid,         // segmentStart(work)
                .notificationSuccess, // rest->work
                .impactLight,         // last3s
                .notificationSuccess  // completed
            ]),
            "Haptic patterns order did not contain expected subsequence: \(captured)"
        )
    }

    func test_disabled_sink_produces_no_patterns() throws {
        let plan = Plan(setsCount: 1, workSeconds: 3, restSeconds: 0, name: "Disabled")
        var captured: [HapticPattern] = []
        let sink = HapticsCueSink(enabled: false) { patterns in
            captured.append(contentsOf: patterns)
        }
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), cues: sink)
        _ = engine.tick(at: Date(timeIntervalSince1970: 0))
        _ = engine.tick(at: Date(timeIntervalSince1970: 1))
        _ = engine.tick(at: Date(timeIntervalSince1970: 3))
        XCTAssertTrue(captured.isEmpty)
    }
}
