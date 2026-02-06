import Foundation

public enum WorkoutEndResult: Sendable, Equatable {
    /// End was requested but needs a second confirmation (anti-mistap guard).
    case requiresConfirmation
    case ended
    case alreadyEnded
    case alreadyCompleted
}

public enum WorkoutRecoveryError: Error, Sendable, Equatable {
    case invalidPlanConfig
}

/// Minimal training session engine (M0).
///
/// Responsibilities:
/// - Owns a `SessionStateMachine` and applies valid transitions
/// - Uses `AbsoluteTimer` for elapsed time (drift-resistant)
/// - Uses `WorkoutStructure` + `WorkoutSegmentScheduler` to emit segment change events
/// - Records pause reasons and end/completion events on the `Session`
public struct WorkoutSessionEngine: Sendable {
    public let planId: UUID?
    public let structure: WorkoutStructure

    public private(set) var session: Session
    public private(set) var stateMachine: SessionStateMachine

    private var timer: AbsoluteTimer
    private var scheduler: WorkoutSegmentScheduler
    private var pendingEndConfirmation: Bool = false

    private var cueSink: CueSink
    private var playbackSink: PlaybackIntentSink
    private var last3sFiredForSegmentStableId: String?

    public init(
        plan: Plan,
        now: Date = Date(),
        cues: CueSink = NoopCueSink(),
        playback: PlaybackIntentSink = NoopPlaybackIntentSink()
    ) throws {
        self.planId = plan.id
        self.structure = WorkoutStructure(setsCount: plan.setsCount, workSeconds: plan.workSeconds, restSeconds: plan.restSeconds)
        self.stateMachine = SessionStateMachine(status: .idle)
        self.timer = AbsoluteTimer(totalSeconds: structure.totalSeconds)
        self.scheduler = WorkoutSegmentScheduler(structure: structure)
        let snapshot = PlanSnapshot(
            planId: plan.id,
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name,
            musicStrategy: plan.musicStrategy,
            capturedAt: now
        )
        self.session = Session(
            status: .idle,
            startedAt: now,
            endedAt: nil,
            planSnapshot: snapshot,
            completedSets: 0,
            totalSets: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            events: []
        )
        self.cueSink = cues
        self.playbackSink = playback
        self.last3sFiredForSegmentStableId = nil

        try start(at: now)
    }

    /// Recovery initializer (3.2.2).
    /// - Note: Restores the engine to `.paused` to avoid surprising audio playback.
    public init(
        recovering snapshot: RecoverableSessionSnapshot,
        now: Date = Date(),
        cues: CueSink = NoopCueSink(),
        playback: PlaybackIntentSink = NoopPlaybackIntentSink()
    ) throws {
        let config = snapshot.session.planSnapshot
        let setsCount = config?.setsCount ?? snapshot.session.totalSets
        let workSeconds = config?.workSeconds ?? snapshot.session.workSeconds
        let restSeconds = config?.restSeconds ?? snapshot.session.restSeconds

        guard setsCount > 0, workSeconds >= 0, restSeconds >= 0 else {
            throw WorkoutRecoveryError.invalidPlanConfig
        }

        self.planId = config?.planId
        self.structure = WorkoutStructure(setsCount: setsCount, workSeconds: workSeconds, restSeconds: restSeconds)
        self.stateMachine = SessionStateMachine(status: .paused)
        self.timer = AbsoluteTimer(totalSeconds: structure.totalSeconds, recoveringElapsedSeconds: snapshot.elapsedSeconds, pausedAt: now)
        self.scheduler = WorkoutSegmentScheduler(structure: structure)
        _ = self.scheduler.update(elapsedSeconds: snapshot.elapsedSeconds)
        self.session = snapshot.session
        self.session.status = .paused
        self.session.endedAt = nil
        let progress = structure.progress(atElapsedSeconds: snapshot.elapsedSeconds)
        self.session.completedSets = progress.completedSets
        self.session.totalSets = setsCount
        self.session.workSeconds = workSeconds
        self.session.restSeconds = restSeconds
        self.session.events.append(.init(name: "recovered", occurredAt: now))
        self.cueSink = cues
        self.playbackSink = playback
        self.last3sFiredForSegmentStableId = nil
        self.pendingEndConfirmation = false
    }

    public mutating func start(at now: Date) throws {
        try stateMachine.start()
        timer.start(at: now)
        session.status = .running
        session.startedAt = now
        pendingEndConfirmation = false
        _ = tick(at: now)
    }

    /// Drives computed progress & segment changes. Safe to call frequently.
    ///
    /// - Returns: `true` if this tick caused the session to become completed.
    @discardableResult
    public mutating func tick(at now: Date) -> Bool {
        let elapsed = timer.elapsedSeconds(at: now)
        let progress = structure.progress(atElapsedSeconds: elapsed)

        session.completedSets = progress.completedSets

        if let change = scheduler.update(elapsedSeconds: elapsed) {
            // Record session-level segment change
            session.events.append(
                .segmentChanged(
                    occurredAt: now,
                    from: change.from?.stableId,
                    to: change.to.stableId
                )
            )
            // Emit cue: segmentStart
            cueSink.emit(.segmentStart(occurredAt: now, segmentId: change.to.stableId, kind: change.to.kind, setIndex: change.to.setIndex))
            playbackSink.emit(
                .segmentChanged(
                    occurredAt: now,
                    from: change.from?.stableId,
                    to: change.to.stableId,
                    kind: change.to.kind,
                    setIndex: change.to.setIndex
                )
            )
            // Emit cue: work/rest transition semantics
            if let from = change.from {
                switch (from.kind, change.to.kind) {
                case (.work, .rest):
                    cueSink.emit(.workToRest(occurredAt: now, from: from.stableId, to: change.to.stableId))
                case (.rest, .work):
                    cueSink.emit(.restToWork(occurredAt: now, from: from.stableId, to: change.to.stableId))
                default:
                    break
                }
            }
            // Reset last3s marker for new segment
            last3sFiredForSegmentStableId = nil
        }

        // last3s cue: when remaining seconds in current segment becomes 3
        if let seg = progress.currentSegment {
            let segId = "\(seg.kind.rawValue)#\(seg.setIndex)"
            if seg.durationSeconds >= 3, progress.currentSegmentRemainingSeconds == 3, last3sFiredForSegmentStableId != segId {
                cueSink.emit(.last3s(occurredAt: now, segmentId: segId))
                last3sFiredForSegmentStableId = segId
            }
        }

        // Auto-complete when time reaches the end.
        if progress.isCompleted, session.status != .completed, session.status != .ended {
            timer.end(at: now)
            do { try stateMachine.complete() } catch { /* ignore; state machine will guard anyway */ }
            session.status = .completed
            session.endedAt = now
            session.events.append(.completed(occurredAt: now))
            cueSink.emit(.completed(occurredAt: now))
            pendingEndConfirmation = false
            return true
        }

        return false
    }

    /// Read-only progress snapshot for UI rendering (does not mutate state).
    public func progress(at now: Date) -> WorkoutProgress {
        let elapsed = timer.elapsedSeconds(at: now)
        return structure.progress(atElapsedSeconds: elapsed)
    }

    /// Snapshot used for persistence-backed recovery (3.2.1).
    public func recoverableSnapshot(at now: Date = Date()) -> RecoverableSessionSnapshot {
        RecoverableSessionSnapshot(session: session, elapsedSeconds: timer.elapsedSeconds(at: now), capturedAt: now)
    }

    public mutating func pause(reason: PauseReason, at now: Date) throws {
        try stateMachine.pause(reason: reason)
        timer.pause(at: now)
        session.status = .paused
        session.events.append(.paused(occurredAt: now, reason: reason.rawValue))
        cueSink.emit(.paused(occurredAt: now))
    }

    public mutating func resume(at now: Date) throws {
        try stateMachine.resume()
        timer.resume(at: now)
        session.status = .running
        session.events.append(.resumed(occurredAt: now))
        cueSink.emit(.resumed(occurredAt: now))
    }

    /// "End" anti-mistap guard:
    /// - First call with `confirmed=false` will return `.requiresConfirmation` (and not end).
    /// - Second call with `confirmed=true` ends the session.
    /// - Alternatively, a long-press UI may call `confirmed=true` directly.
    public mutating func end(at now: Date, confirmed: Bool) throws -> WorkoutEndResult {
        if session.status == .ended { return .alreadyEnded }
        if session.status == .completed { return .alreadyCompleted }

        if !confirmed {
            pendingEndConfirmation = true
            return .requiresConfirmation
        }

        // If confirmed=true, we allow ending even without a prior request (e.g. long-press).
        pendingEndConfirmation = false

        timer.end(at: now)
        try stateMachine.end()
        session.status = .ended
        session.endedAt = now
        session.events.append(.ended(occurredAt: now))
        return .ended
    }

    public mutating func setMusicSelectionOverride(_ selection: MusicSelection?, at now: Date = Date()) {
        var overrides = session.overrides ?? SessionOverrides()
        overrides.musicSelection = selection
        session.overrides = overrides
        if let selection {
            session.events.append(.init(name: "musicOverride", occurredAt: now, attributes: ["externalId": selection.externalId]))
        } else {
            session.events.append(.init(name: "musicOverrideCleared", occurredAt: now))
        }
    }

    public mutating func recordInterruption(_ event: InterruptionEvent) {
        session.events.append(event.asSessionEventRecord())
    }

    public mutating func recordPreflight(_ report: WorkoutPreflightReport, occurredAt: Date = Date()) {
        session.events.append(report.asSessionEventRecord(occurredAt: occurredAt))
    }

    public mutating func recordDegrade(_ reason: DegradeReason, occurredAt: Date = Date(), attributes: [String: String] = [:]) {
        var attrs = attributes
        attrs["reason"] = reason.rawValue
        session.events.append(.init(name: "degraded", occurredAt: occurredAt, attributes: attrs))
    }

    /// Record an interruption event and apply safety decisions (3.1.3).
    public mutating func handleInterruption(
        _ event: InterruptionEvent,
        safetyPolicy: HeadphoneDisconnectSafetyPolicy = HeadphoneDisconnectSafetyPolicy()
    ) {
        recordInterruption(event)

        if safetyPolicy.decide(for: event) == .requireSafetyPause, session.status == .running {
            try? pause(reason: .safety, at: event.occurredAt)
        }
    }

    /// Apply Siri silence threshold behavior (3.1.2).
    public mutating func handleSiriInterruption(durationSeconds: TimeInterval, at now: Date, policy: SiriInterruptionPolicy) {
        let decision = policy.decide(durationSeconds: durationSeconds)
        session.events.append(
            .init(
                name: "siriInterruption",
                occurredAt: now,
                attributes: [
                    "durationSeconds": String(durationSeconds),
                    "decision": decision == .pause ? "pause" : "ignore",
                ]
            )
        )

        if decision == .pause, session.status == .running {
            try? pause(reason: .interruption, at: now)
        }
    }
}
