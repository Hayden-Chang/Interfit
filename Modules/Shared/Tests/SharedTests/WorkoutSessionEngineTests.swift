import XCTest
@testable import Shared

private final class CollectingCueSink: @unchecked Sendable, CueSink {
    var events: [CueEventRecord] = []
    func emit(_ event: CueEventRecord) { events.append(event) }
}

private final class CollectingPlaybackIntentSink: @unchecked Sendable, PlaybackIntentSink {
    var intents: [PlaybackIntent] = []
    func emit(_ intent: PlaybackIntent) { intents.append(intent) }
}

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

    func test_tick_afterEnded_doesNotEmitNewEventsOrIntentsOrCues() throws {
        let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 5, name: "EndTick")
        let cues = CollectingCueSink()
        let playback = CollectingPlaybackIntentSink()
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0), cues: cues, playback: playback)

        // Ensure at least one tick happened at a non-zero time.
        _ = engine.tick(at: Date(timeIntervalSince1970: 1))

        _ = try engine.end(at: Date(timeIntervalSince1970: 2), confirmed: false)
        _ = try engine.end(at: Date(timeIntervalSince1970: 3), confirmed: true)
        XCTAssertEqual(engine.session.status, .ended)

        let endedAt = engine.session.endedAt
        let sessionEventsCount = engine.session.events.count
        let cueCount = cues.events.count
        let intentCount = playback.intents.count

        // Tick far in the future should be a no-op for an ended session.
        let didComplete = engine.tick(at: Date(timeIntervalSince1970: 100))
        XCTAssertFalse(didComplete)
        XCTAssertEqual(engine.session.status, .ended)
        XCTAssertEqual(engine.session.endedAt, endedAt)
        XCTAssertEqual(engine.session.events.count, sessionEventsCount)
        XCTAssertEqual(cues.events.count, cueCount)
        XCTAssertEqual(playback.intents.count, intentCount)
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

    func test_recordInterruption_appendsSessionEvent() throws {
        let plan = Plan(setsCount: 1, workSeconds: 5, restSeconds: 0, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        engine.recordInterruption(InterruptionEvent(kind: .routeChanged, occurredAt: Date(timeIntervalSince1970: 1), attributes: ["reason": "oldDeviceUnavailable"]))

        XCTAssertEqual(engine.session.events.last?.name, "interruption")
        XCTAssertEqual(engine.session.events.last?.attributes["kind"], "routeChanged")
        XCTAssertEqual(engine.session.events.last?.attributes["reason"], "oldDeviceUnavailable")
    }

    func test_handleInterruption_routeChangedOldDeviceUnavailable_triggersSafetyPause_andRecordsEvents() throws {
        let plan = Plan(setsCount: 1, workSeconds: 5, restSeconds: 0, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        engine.handleInterruption(
            InterruptionEvent(
                kind: .routeChanged,
                occurredAt: Date(timeIntervalSince1970: 1),
                attributes: ["reason": "oldDeviceUnavailable"]
            )
        )

        XCTAssertEqual(engine.session.status, .paused)
        XCTAssertEqual(engine.session.events.last?.kind, .paused)
        XCTAssertEqual(engine.session.events.last?.attributes["reason"], PauseReason.safety.rawValue)

        XCTAssertTrue(engine.session.events.contains(where: { $0.name == "interruption" }))
    }

    func test_recoveryInitializer_restoresPausedElapsed_andAllowsResume() throws {
        let plan = Plan(setsCount: 2, workSeconds: 10, restSeconds: 0, name: "Test")
        let t0 = Date(timeIntervalSince1970: 0)
        var engine = try WorkoutSessionEngine(plan: plan, now: t0)

        _ = engine.tick(at: Date(timeIntervalSince1970: 7))
        try engine.pause(reason: .user, at: Date(timeIntervalSince1970: 7))

        let snapshot = RecoverableSessionSnapshot(session: engine.session, elapsedSeconds: 7, capturedAt: Date(timeIntervalSince1970: 7))
        var recovered = try WorkoutSessionEngine(recovering: snapshot, now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(recovered.session.status, .paused)
        XCTAssertEqual(recovered.progress(at: Date(timeIntervalSince1970: 100)).elapsedSeconds, 7)
        XCTAssertEqual(recovered.progress(at: Date(timeIntervalSince1970: 200)).elapsedSeconds, 7)

        try recovered.resume(at: Date(timeIntervalSince1970: 200))
        _ = recovered.tick(at: Date(timeIntervalSince1970: 210))
        XCTAssertEqual(recovered.progress(at: Date(timeIntervalSince1970: 210)).elapsedSeconds, 17)
    }

    func test_recoveryInitializer_doesNotEmitSegmentChangedOnFirstTick_atSegmentBoundary() throws {
        let t0 = Date(timeIntervalSince1970: 0)
        let snapshotSession = Session(
            status: .paused,
            startedAt: t0,
            endedAt: nil,
            planSnapshot: PlanSnapshot(planId: nil, setsCount: 2, workSeconds: 10, restSeconds: 10, name: "Test", capturedAt: t0),
            completedSets: 0,
            totalSets: 2,
            workSeconds: 10,
            restSeconds: 10,
            events: []
        )
        let snapshot = RecoverableSessionSnapshot(session: snapshotSession, elapsedSeconds: 10, capturedAt: Date(timeIntervalSince1970: 10))

        var recovered = try WorkoutSessionEngine(recovering: snapshot, now: Date(timeIntervalSince1970: 100))
        let eventsBeforeTick = recovered.session.events.count

        _ = recovered.tick(at: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(recovered.session.events.count, eventsBeforeTick)
        XCTAssertEqual(recovered.progress(at: Date(timeIntervalSince1970: 100)).currentSegment?.kind, .rest)
        XCTAssertEqual(recovered.session.completedSets, 1)
    }

    func test_recordPreflight_appendsPreflightEvent() throws {
        let plan = Plan(setsCount: 1, workSeconds: 5, restSeconds: 0, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        let report = WorkoutPreflightReport(name: "preStart", status: .ok, durationMs: 12, attributes: ["k": "v"])
        engine.recordPreflight(report, occurredAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(engine.session.events.last?.name, "preflight")
        XCTAssertEqual(engine.session.events.last?.attributes["name"], "preStart")
        XCTAssertEqual(engine.session.events.last?.attributes["status"], "ok")
        XCTAssertEqual(engine.session.events.last?.attributes["durationMs"], "12")
        XCTAssertEqual(engine.session.events.last?.attributes["k"], "v")
    }

    func test_recordDegrade_appendsDegradedEvent() throws {
        let plan = Plan(setsCount: 1, workSeconds: 5, restSeconds: 0, name: "Test")
        var engine = try WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))

        engine.recordDegrade(.fallbackDueToOffline, occurredAt: Date(timeIntervalSince1970: 2), attributes: ["source": "playback"])

        XCTAssertEqual(engine.session.events.last?.name, "degraded")
        XCTAssertEqual(engine.session.events.last?.occurredAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(engine.session.events.last?.attributes["reason"], "fallbackDueToOffline")
        XCTAssertEqual(engine.session.events.last?.attributes["source"], "playback")
    }
}
