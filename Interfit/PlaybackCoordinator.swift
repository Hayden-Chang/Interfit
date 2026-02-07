import Foundation
import Shared
import Audio

private actor PlaybackCoordinatorState {
    private var playbackClaim: AudioSessionObservationToken?
    private var lastSegmentStableId: String?
    private var currentSelection: MusicSelection?
    private var lastDecision: PlaybackSegmentStartAction?
    private var lastFailureOutcome: PlaybackFailureOutcome?
    private var isPausedByTimer: Bool = false
    private var isPlaybackDisabledForSession: Bool = false
    private var lastSegmentKind: WorkoutSegmentKind?
    private var lastSegmentSetIndex: Int?

    private let selectionProvider: @Sendable (WorkoutSegmentKind, Int) -> MusicSelection?
    private let selectionApplier: @Sendable (MusicSelection) async throws -> Void
    private let selectionDirectiveApplier: @Sendable (MusicPlaybackDirective) async throws -> Void
    private let pausePlayback: @Sendable () async -> Void
    private let resumePlayback: @Sendable () async -> Void
    private let stopPlayback: @Sendable () async -> Void
    private let failureClassifier: @Sendable (Error) -> PlaybackFailureKind
    private let onFallback: @Sendable (PlaybackFailureKind, PlaybackFailureOutcome) -> Void

    private var pendingSelectionExternalId: String?
    private var applyTask: Task<Void, Never>?

    init(
        selectionProvider: @escaping @Sendable (WorkoutSegmentKind, Int) -> MusicSelection?,
        selectionApplier: @escaping @Sendable (MusicSelection) async throws -> Void,
        selectionDirectiveApplier: @escaping @Sendable (MusicPlaybackDirective) async throws -> Void,
        pausePlayback: @escaping @Sendable () async -> Void,
        resumePlayback: @escaping @Sendable () async -> Void,
        stopPlayback: @escaping @Sendable () async -> Void,
        failureClassifier: @escaping @Sendable (Error) -> PlaybackFailureKind,
        onFallback: @escaping @Sendable (PlaybackFailureKind, PlaybackFailureOutcome) -> Void
    ) {
        self.selectionProvider = selectionProvider
        self.selectionApplier = selectionApplier
        self.selectionDirectiveApplier = selectionDirectiveApplier
        self.pausePlayback = pausePlayback
        self.resumePlayback = resumePlayback
        self.stopPlayback = stopPlayback
        self.failureClassifier = failureClassifier
        self.onFallback = onFallback
    }

    func emit(_ intent: PlaybackIntent) {
        if playbackClaim == nil {
            playbackClaim = AudioSessionManager.shared.beginPlayback(mixWithOthers: true)
        }

        switch intent {
        case .paused:
            guard !isPausedByTimer else { return }
            isPausedByTimer = true
            applyTask?.cancel()
            pendingSelectionExternalId = nil
            Task { await pausePlayback() }
        case .resumed:
            guard isPausedByTimer else { return }
            isPausedByTimer = false
            if currentSelection != nil {
                Task { await resumePlayback() }
            }
            if !isPlaybackDisabledForSession,
               currentSelection == nil,
               let kind = lastSegmentKind,
               let setIndex = lastSegmentSetIndex,
               let selection = selectionProvider(kind, setIndex)
            {
                pendingSelectionExternalId = selection.externalId
                applyTask?.cancel()
                applyTask = Task { await applySelectionWithRetry(selection) }
            }
        case .stop:
            isPausedByTimer = false
            applyTask?.cancel()
            pendingSelectionExternalId = nil
            Task { await stopPlayback() }
        case let .segmentChanged(_, _, to, kind, setIndex):
            lastSegmentStableId = to
            lastSegmentKind = kind
            lastSegmentSetIndex = setIndex
            if isPlaybackDisabledForSession { return }

            let nextSelection = selectionProvider(kind, setIndex)
            let decision = PlaybackSegmentStartDecision.decide(current: currentSelection, next: nextSelection)
            lastDecision = decision
            switch decision {
            case .noChange:
                break
            case let .switchSelection(sel, _):
                pendingSelectionExternalId = sel.externalId
                applyTask?.cancel()
                applyTask = Task { await applySelectionWithRetry(sel) }
            case let .applyDirective(directive):
                Task {
                    do {
                        try await selectionDirectiveApplier(directive)
                    } catch {
                        let kind = failureClassifier(error)
                        let outcome = PlaybackFailureFallback.decide(
                            context: .init(
                                hasCurrentPlayback: currentSelection != nil,
                                cuesEnabled: true
                            )
                        )
                        onFallback(kind, .init(action: outcome.action, degradeReason: kind.degradeReason))
                    }
                }
            }
        }
    }

    func reportNextSegmentLoadFailed() {
        let outcome = PlaybackFailureFallback.decide(
            context: .init(
                hasCurrentPlayback: currentSelection != nil,
                cuesEnabled: true
            )
        )
        lastFailureOutcome = outcome

        switch outcome.action {
        case .continueCurrent:
            break
        case .cuesOnly, .silence:
            currentSelection = nil
        }
    }

    private func applySelectionWithRetry(_ selection: MusicSelection) async {
        var attempt = 0

        while !Task.isCancelled {
            let stillPending = pendingSelectionExternalId == selection.externalId
            let hasCurrentPlayback = currentSelection != nil
            guard stillPending else { return }

            do {
                try await selectionApplier(selection)
                if pendingSelectionExternalId == selection.externalId {
                    currentSelection = selection
                    lastFailureOutcome = nil
                    pendingSelectionExternalId = nil
                }
                return
            } catch {
                let kind = failureClassifier(error)
                let decision = PlaybackFailureRetryPolicy.decide(
                    context: .init(attempt: attempt, kind: kind, hasCurrentPlayback: hasCurrentPlayback, cuesEnabled: true)
                )

                switch decision {
                case let .retry(afterSeconds: seconds):
                    attempt += 1
                    let nanos = UInt64(max(0, seconds) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                case let .fallback(outcome):
                    if pendingSelectionExternalId == selection.externalId {
                        lastFailureOutcome = outcome
                        pendingSelectionExternalId = nil
                        if kind == .permission || kind == .restriction {
                            isPlaybackDisabledForSession = true
                        }
                        switch outcome.action {
                        case .continueCurrent:
                            break
                        case .cuesOnly, .silence:
                            currentSelection = nil
                        }
                    }
                    onFallback(kind, outcome)
                    return
                }
            }
        }
    }
}

/// App-layer playback coordinator (2.2.x).
///
/// For now this is a minimal `PlaybackIntentSink` that:
/// - claims an `AVAudioSession` playback slot via `AudioSessionManager`
/// - consumes pure segment-start decisions (future: drive MusicKit/local playback)
final class PlaybackCoordinator: @unchecked Sendable, PlaybackIntentSink {
    private let state: PlaybackCoordinatorState

    init(
        selectionProvider: @escaping @Sendable (WorkoutSegmentKind, Int) -> MusicSelection? = { _, _ in nil },
        selectionApplier: @escaping @Sendable (MusicSelection) async throws -> Void = { _ in },
        selectionDirectiveApplier: @escaping @Sendable (MusicPlaybackDirective) async throws -> Void = { _ in },
        pausePlayback: @escaping @Sendable () async -> Void = {},
        resumePlayback: @escaping @Sendable () async -> Void = {},
        stopPlayback: @escaping @Sendable () async -> Void = {},
        failureClassifier: @escaping @Sendable (Error) -> PlaybackFailureKind = { _ in .unknown },
        onFallback: @escaping @Sendable (PlaybackFailureKind, PlaybackFailureOutcome) -> Void = { _, _ in }
    ) {
        state = PlaybackCoordinatorState(
            selectionProvider: selectionProvider,
            selectionApplier: selectionApplier,
            selectionDirectiveApplier: selectionDirectiveApplier,
            pausePlayback: pausePlayback,
            resumePlayback: resumePlayback,
            stopPlayback: stopPlayback,
            failureClassifier: failureClassifier,
            onFallback: onFallback
        )
    }

    func emit(_ intent: PlaybackIntent) {
        Task { await state.emit(intent) }
    }

    func reportNextSegmentLoadFailed() {
        Task { await state.reportNextSegmentLoadFailed() }
    }
}
