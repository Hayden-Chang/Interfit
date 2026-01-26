import XCTest
@testable import Shared

final class WorkoutSessionEngineTests: XCTestCase {
    func test_pause_resume_recordsReason_andStateTransitions() throws {
        let plan = Plan(setsCount: 2, workSeconds: 10, restSeconds: 0, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(engine.session.status, .running)

        try engine.pause(reason: .user, at: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(engine.session.status, .paused)
        XCTAssertEqual(engine.session.events.last?.kind, .paused)
        XCTAssertEqual(engine.session.events.last?.attributes["reason"], "user")

        // While paused, ticking later should not advance elapsed time (AbsoluteTimer behavior),
        // but it's still safe to tick.
        _ = engine.tick(at: Date(timeIntervalSince1970: 100))

        try engine.resume(at: Date(timeIntervalSince1970: 101))
        XCTAssertEqual(engine.session.status, .running)
        XCTAssertEqual(engine.session.events.last?.kind, .resumed)
    }

    func test_end_requiresConfirmation_andSetsEndedStatus() throws {
        let plan = Plan(setsCount: 3, workSeconds: 10, restSeconds: 5, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        let r1 = try engine.end(at: Date(timeIntervalSince1970: 2), confirmed: false)
        XCTAssertEqual(r1, .requiresConfirmation)
        XCTAssertNotEqual(engine.session.status, .ended)

        let r2 = try engine.end(at: Date(timeIntervalSince1970: 3), confirmed: true)
        XCTAssertEqual(r2, .ended)
        XCTAssertEqual(engine.session.status, .ended)
        XCTAssertEqual(engine.session.events.last?.kind, .ended)
    }

    func test_completion_setsCompletedStatus_notEnded() throws {
        let plan = Plan(setsCount: 1, workSeconds: 5, restSeconds: 0, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(engine.session.status, .running)
        XCTAssertFalse(engine.session.events.contains(where: { $0.kind == .completed }))

        // Exactly at end should complete.
        let didComplete = engine.tick(at: Date(timeIntervalSince1970: 5))
        XCTAssertTrue(didComplete)
        XCTAssertEqual(engine.session.status, .completed)
        XCTAssertEqual(engine.session.endedAt, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(engine.session.events.last?.kind, .completed)

        // Ending after completion should be a no-op result.
        let r = try engine.end(at: Date(timeIntervalSince1970: 6), confirmed: true)
        XCTAssertEqual(r, .alreadyCompleted)
        XCTAssertEqual(engine.session.status, .completed)
    }
}

