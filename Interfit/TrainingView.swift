import SwiftUI
import Shared
import Persistence
import Audio
import AVFoundation
import Network
import UserNotifications

struct TrainingView: View {
    let plan: Plan?
    let recoverableSnapshot: RecoverableSessionSnapshot?
    let onExitToCleanTraining: (() -> Void)?

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var engine: WorkoutSessionEngine?
    @State private var now: Date = Date()
    @StateObject private var nowPlaying = NowPlayingManager()
    @StateObject private var musicPlaybackClient = MusicPlaybackClient.shared

    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize: CGFloat = 72

    private enum SummaryDismissAction: Sendable {
        case restart
        case clean
    }

    @State private var isShowingSummary: Bool = false
    @State private var summaryOutcome: TrainingSummaryView.Outcome?
    @State private var summarySession: Session?
    @State private var summaryPresentedForSessionId: UUID?
    @State private var summaryDismissAction: SummaryDismissAction = .clean
    @State private var isShowingEndConfirm: Bool = false
    @State private var didConfirmEndFromAlert: Bool = false
    @State private var didPersistSession: Bool = false
    @State private var isShowingBackgroundTimingNotice: Bool = false
    @State private var audioSessionObservation: AudioSessionObservationToken?
    @State private var lastRecoverableSnapshotPersistedAt: Date?
    @State private var didTriggerStartPreflight: Bool = false
    @State private var didSimulateHeadphoneDisconnect: Bool = false
    @State private var siriSecondaryAudioSilenceBeganAt: Date?
    @State private var ignoreRecoverySnapshot: Bool = false
    @State private var degradeBanner: DegradeReason?

    @AppStorage(BackgroundTimingNoticePolicy.userDefaultsKey) private var didShowBackgroundTimingNotice: Bool = false

    private let persistenceStore = CoreDataPersistenceStore()
    private var sessionRepository: any SessionRepository { persistenceStore }
    private var recoverableSessionRepository: any RecoverableSessionRepository { persistenceStore }

    private let tickTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(
        plan: Plan? = nil,
        recoverableSnapshot: RecoverableSessionSnapshot? = nil,
        onExitToCleanTraining: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.recoverableSnapshot = recoverableSnapshot
        self.onExitToCleanTraining = onExitToCleanTraining
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: contentSpacing) {
                    if engine == nil, plan == nil, recoverableSnapshot == nil {
                        Text("No active training")
                            .font(.title.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Start a workout from Train tab.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)
                    } else {
                        Text(segmentTitle)
                            .font(.title.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let nowPlayingDisplay = musicPlaybackClient.nowPlayingDisplay {
                            interfitNowPlayingView(nowPlayingDisplay)
                        }

                        if shouldShowCircularCountdown {
                            VStack(spacing: countdownBlockSpacing) {
                                Text(formattedCountdown)
                                    .font(.system(size: countdownDisplayFontSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity, alignment: .center)

                                circularCountdown
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            Text(formattedCountdown)
                                .font(.system(size: countdownDisplayFontSize, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if isSafetyPausedByHeadphoneDisconnect {
                            Text("Paused for safety (headphones disconnected). Tap Resume to continue.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer(minLength: 0)

                        if !timelineSegments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(setProgressText)
                                    .font(.system(size: setProgressFontSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)

                                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                                    TimelineProgressBar(
                                        segments: timelineSegments,
                                        progress: overallTimelineProgress(at: context.date)
                                    )
                                    .accessibilityLabel("Overall workout timeline")
                                    .accessibilityValue(setProgressText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .padding()
        .navigationTitle(trainingNameForNavigationBar)
        .onAppear { startIfNeeded() }
        .onChange(of: isShowingSummary) { isPresented in
            guard !isPresented else { return }
            handleSummaryDismissal()
        }
        .onDisappear {
            if engine == nil {
                cleanupSessionSideEffects()
            }
        }
        .onReceive(tickTimer) { now in tickIfNeeded(now: now) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            scheduleBackgroundSegmentCuesIfNeeded()
            refreshBackgroundAudioKeepAlive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            scheduleBackgroundSegmentCuesIfNeeded()
            refreshBackgroundAudioKeepAlive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            SegmentCueNotificationScheduler.cancelAll()
            refreshBackgroundAudioKeepAlive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NowPlayingManager.remotePlayNotification)) { _ in
            handleRemotePlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: NowPlayingManager.remotePauseNotification)) { _ in
            handleRemotePause()
        }
        .onReceive(NotificationCenter.default.publisher(for: NowPlayingManager.remoteToggleNotification)) { _ in
            handleRemoteToggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.silenceSecondaryAudioHintNotification)) { notification in
            handleSiriSilenceSecondaryAudioHint(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .interfitTerminateCurrentTrainingForReplacement)) { _ in
            terminateWorkoutForPlanReplacement()
        }
        .navigationDestination(isPresented: $isShowingSummary) {
            if let summaryOutcome, let plan = summaryPlanForSummary {
                TrainingSummaryView(
                    outcome: summaryOutcome,
                    plan: plan,
                    session: summarySession,
                    onTrainAgain: {
                        summaryDismissAction = .restart
                        isShowingSummary = false
                    }
                )
            } else {
                VStack(spacing: 12) {
                    Text("Summary unavailable")
                        .font(.title2.bold())
                    Text("We couldn’t resolve a plan to show the summary.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .alert("End workout?", isPresented: $isShowingEndConfirm) {
            Button("End", role: .destructive) { didConfirmEndFromAlert = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the workout and show a summary.")
        }
        .alert(BackgroundTimingNoticePolicy.title, isPresented: $isShowingBackgroundTimingNotice) {
            Button("Continue", role: .cancel) {}
        } message: {
            Text(BackgroundTimingNoticePolicy.message)
        }
        .alert(
            "Music unavailable",
            isPresented: Binding(
                get: { degradeBanner != nil },
                set: { isPresented in
                    if !isPresented {
                        degradeBanner = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let degradeBanner {
                Text("\(degradeBanner.message)\n\nTry: subscribe/authorize Apple Music, pick another song, or check network.")
            } else {
                Text("Training will continue with timer and cues only.")
            }
        }
        .onChange(of: didConfirmEndFromAlert) { confirmed in
            guard confirmed else { return }
            didConfirmEndFromAlert = false
            isShowingEndConfirm = false
            endWorkout(confirmed: true)
        }
        .toolbar {
            if engine?.session.status == .running || engine?.session.status == .paused {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("End", role: .destructive) {
                        endWorkout(confirmed: false)
                    }
                }
            }
        }
    }

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var contentSpacing: CGFloat {
        isCompactHeight ? 12 : 16
    }

    private var countdownDisplayFontSize: CGFloat {
        isCompactHeight ? min(countdownFontSize, 56) : countdownFontSize
    }

    private var countdownBlockSpacing: CGFloat {
        isCompactHeight ? 8 : 12
    }

    private var setProgressFontSize: CGFloat {
        isCompactHeight ? 28 : 34
    }

    private var trainingNameForNavigationBar: String {
        let name = plan?.name ?? recoverableSnapshot?.session.planSnapshot?.name ?? "Training"
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Training" : trimmed
    }

    private func interfitNowPlayingView(_ display: MusicPlaybackClient.NowPlayingDisplay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Now Playing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(display.title)
                .font(.headline)
                .lineLimit(1)
            Text(display.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing")
        .accessibilityValue("\(display.title), \(display.artist)")
    }

    private func startIfNeeded() {
        guard engine == nil else { return }
        degradeBanner = nil

        let sinks: [CueSink] = [
            // Avoid persistent ducking so Apple Music volume stays consistent with the Music app.
            AudioCueSink(enabled: true, options: .init(duckOthers: false, mixWithOthers: true)),
            SpeechCueSink(enabled: true),
            HapticsCueSink(enabled: true),
        ]
        let cues = CueCoalescingSink(MultiCueSink(sinks))

        let strategy = recoverableSnapshot?.session.planSnapshot?.musicStrategy ?? plan?.musicStrategy
        let simulatePlaybackLoadFailure = ProcessInfo.processInfo.arguments.contains("-simulatePlaybackLoadFailure")
        let debugSelection = MusicSelection(
            source: .appleMusic,
            type: .track,
            externalId: "debug.fail.track",
            displayTitle: "Debug Track (Simulated Failure)",
            playMode: .continue
        )

        let playback = PlaybackCoordinator(
            selectionProvider: { kind, setIndex in
                if simulatePlaybackLoadFailure, kind == .work, setIndex == 1 {
                    return debugSelection
                }
                return strategy?.selection(for: kind, setIndex: setIndex)
            },
            selectionApplier: { selection in
                if simulatePlaybackLoadFailure {
                    struct SimulatedPlaybackLoadError: Error {}
                    throw SimulatedPlaybackLoadError()
                }
                try await MusicPlaybackClient.apply(selection: selection)
            },
            selectionDirectiveApplier: { directive in
                try await MusicPlaybackClient.applyDirective(directive)
            },
            pausePlayback: {
                await MusicPlaybackClient.pause()
            },
            resumePlayback: {
                await MusicPlaybackClient.resume()
            },
            stopPlayback: {
                await MusicPlaybackClient.stop()
            },
            failureClassifier: { error in
                simulatePlaybackLoadFailure ? .timeout : MusicPlaybackClient.classify(error)
            },
            onFallback: { kind, outcome in
            Task { @MainActor in
                guard var eng = engine else { return }
                eng.recordDegrade(
                    outcome.degradeReason,
                    attributes: [
                        "source": "playback",
                        "kind": kind.rawValue,
                        "action": String(describing: outcome.action),
                    ]
                )
                engine = eng
                degradeBanner = outcome.degradeReason
            }
        })

        if !ignoreRecoverySnapshot, let recoverableSnapshot {
            engine = try? WorkoutSessionEngine(recovering: recoverableSnapshot, now: Date(), cues: cues, playback: playback)
        } else if let plan {
            engine = try? WorkoutSessionEngine(plan: plan, now: Date(), cues: cues, playback: playback)
        } else {
            return
        }
        startObservingAudioSession()
        triggerStartPreflightIfNeeded()
        nowPlaying.start()
        nowPlaying.update(planName: plan?.name, progress: engine?.progress(at: now), sessionStatus: engine?.session.status ?? .idle)
        Task { @MainActor in
            IdleTimerClient.setDisabled(true)
        }
        showBackgroundTimingNoticeIfNeeded()
        simulateHeadphoneDisconnectIfRequested()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refreshBackgroundAudioKeepAlive()
    }

    private func tickIfNeeded(now: Date) {
        if isShowingSummary { return }
        guard var eng = engine else { return }
        _ = eng.tick(at: now)
        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
        persistRecoverableSnapshotIfNeeded(eng, now: now)

        if !isShowingSummary, summaryPresentedForSessionId != eng.session.id {
            switch eng.session.status {
            case .completed:
                persistSessionIfNeeded(eng.session)
                markCurrentTrainingAsTerminal()
                summaryOutcome = .completed
                summarySession = eng.session
                summaryPresentedForSessionId = eng.session.id
                summaryDismissAction = .clean
                isShowingSummary = true
                cleanupSessionSideEffects()
            case .ended:
                persistSessionIfNeeded(eng.session)
                markCurrentTrainingAsTerminal()
                summaryOutcome = .ended
                summarySession = eng.session
                summaryPresentedForSessionId = eng.session.id
                summaryDismissAction = .clean
                isShowingSummary = true
                cleanupSessionSideEffects()
            default:
                break
            }
        }
    }

    private var progress: WorkoutProgress? {
        guard let engine else { return nil }
        return engine.progress(at: now)
    }

    private var segmentTitle: String {
        guard let progress else { return "Idle" }
        guard let segment = progress.currentSegment else {
            return progress.isCompleted ? "Completed" : "Idle"
        }
        switch segment.kind {
        case .work: return "Work"
        case .rest: return "Rest"
        }
    }

    private func startObservingAudioSession() {
        guard audioSessionObservation == nil else { return }
        audioSessionObservation = AudioSessionManager.shared.startObserving { event in
            let mapped: InterruptionEvent
            switch event {
            case .interruptionBegan:
                mapped = InterruptionEvent(kind: .audioSessionInterruptionBegan)
            case let .interruptionEnded(shouldResume):
                mapped = InterruptionEvent(kind: .audioSessionInterruptionEnded, attributes: ["shouldResume": shouldResume ? "true" : "false"])
            case let .routeChanged(reason):
                mapped = InterruptionEvent(kind: .routeChanged, attributes: ["reason": reason.rawValue])
            }
            Task { @MainActor in
                guard var eng = engine else { return }
                eng.handleInterruption(mapped)
                engine = eng
            }
        }
    }

    private func stopObservingAudioSession() {
        audioSessionObservation?.cancel()
        audioSessionObservation = nil
    }

    private func handleSiriSilenceSecondaryAudioHint(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt else { return }
        guard let hint = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: raw) else { return }

        switch hint {
        case .begin:
            siriSecondaryAudioSilenceBeganAt = Date()
        case .end:
            let endedAt = Date()
            let beganAt = siriSecondaryAudioSilenceBeganAt ?? endedAt
            siriSecondaryAudioSilenceBeganAt = nil
            let duration = max(0, endedAt.timeIntervalSince(beganAt))

            Task { @MainActor in
                guard var eng = engine else { return }
                eng.handleSiriInterruption(durationSeconds: duration, at: endedAt, policy: SiriInterruptionSettingsStore.policy)
                engine = eng
                now = endedAt
                nowPlaying.update(planName: plan?.name, progress: eng.progress(at: endedAt), sessionStatus: eng.session.status)
                persistRecoverableSnapshotIfNeeded(eng, now: endedAt, force: true)
            }
        @unknown default:
            break
        }
    }

    private var formattedCountdown: String {
        guard let progress else { return "00:00" }
        let seconds = progress.currentSegmentRemainingSeconds
        return formatMMSS(seconds)
    }

    private var setProgressText: String {
        guard let progress else { return "0/0" }
        let total = max(1, progress.totalSets)
        if let seg = progress.currentSegment {
            let current = min(max(1, seg.setIndex), total)
            return "\(current)/\(total)"
        }
        return "\(total)/\(total)"
    }

    private var timelineStructure: WorkoutStructure? {
        if let engine {
            return engine.structure
        }
        if let plan {
            return WorkoutStructure(
                setsCount: plan.setsCount,
                workSeconds: plan.workSeconds,
                restSeconds: plan.restSeconds
            )
        }
        if let snapshot = recoverableSnapshot?.session.planSnapshot {
            return WorkoutStructure(
                setsCount: snapshot.setsCount,
                workSeconds: snapshot.workSeconds,
                restSeconds: snapshot.restSeconds
            )
        }
        return nil
    }

    private var timelineSegments: [TimelineBarSegment] {
        guard let structure = timelineStructure, structure.setsCount > 0 else { return [] }

        var segments: [TimelineBarSegment] = []
        for setIndex in 1...structure.setsCount {
            if structure.workSeconds > 0 {
                segments.append(.init(kind: .work, setIndex: setIndex, durationSeconds: structure.workSeconds))
            }
            if structure.restSeconds > 0 {
                segments.append(.init(kind: .rest, setIndex: setIndex, durationSeconds: structure.restSeconds))
            }
        }
        return segments
    }

    private func overallTimelineProgress(at date: Date) -> Double {
        guard !timelineSegments.isEmpty else { return 0 }
        let total = timelineSegments.reduce(0) { $0 + $1.durationSeconds }
        guard total > 0 else { return 0 }
        let elapsed = min(max(0, overallTimelineElapsedSeconds(at: date)), Double(total))
        return elapsed / Double(total)
    }

    private func overallTimelineElapsedSeconds(at date: Date) -> Double {
        guard let structure = timelineStructure else { return 0 }

        let cycleSeconds = max(0, structure.workSeconds + structure.restSeconds)
        guard cycleSeconds > 0 else { return 0 }

        let totalTimelineSeconds = Double(cycleSeconds * structure.setsCount)

        if let engine {
            let preciseEngineElapsed = max(0, engine.elapsedTimeInterval(at: date))
            let engineProgress = engine.progress(at: date)
            if engineProgress.isCompleted {
                return totalTimelineSeconds
            }

            if let segment = engineProgress.currentSegment {
                let base = Double(max(0, segment.setIndex - 1) * cycleSeconds)
                let segmentStart = engineSegmentStartElapsedSeconds(segment: segment, structure: structure)
                let rawSegmentElapsed = preciseEngineElapsed - segmentStart
                let segmentElapsed = min(max(0, rawSegmentElapsed), Double(segment.durationSeconds))
                switch segment.kind {
                case .work:
                    return base + segmentElapsed
                case .rest:
                    return base + Double(structure.workSeconds) + segmentElapsed
                }
            }

            return min(preciseEngineElapsed, totalTimelineSeconds)
        }

        guard let progress else { return 0 }
        if let segment = progress.currentSegment {
            let completedCycles = max(0, segment.setIndex - 1)
            let base = completedCycles * cycleSeconds
            switch segment.kind {
            case .work:
                return Double(base + progress.currentSegmentElapsedSeconds)
            case .rest:
                return Double(base + structure.workSeconds + progress.currentSegmentElapsedSeconds)
            }
        }

        if progress.isCompleted {
            return totalTimelineSeconds
        }

        return min(Double(progress.elapsedSeconds), totalTimelineSeconds)
    }

    private func engineSegmentStartElapsedSeconds(segment: WorkoutSegment, structure: WorkoutStructure) -> Double {
        let completedCycles = max(0, segment.setIndex - 1)
        let cycleSeconds = max(0, structure.workSeconds + structure.restSeconds)
        let base = Double(completedCycles * cycleSeconds)
        switch segment.kind {
        case .work:
            return base
        case .rest:
            return base + Double(structure.workSeconds)
        }
    }

    private var isSafetyPausedByHeadphoneDisconnect: Bool {
        guard let engine else { return false }
        guard engine.session.status == .paused else { return false }

        let lastPauseReason = engine.session.events.last(where: { $0.kind == .paused })?.attributes["reason"]
        guard lastPauseReason == PauseReason.safety.rawValue else { return false }

        let lastInterruption = engine.session.events.last(where: { $0.name == "interruption" })
        return lastInterruption?.attributes["reason"] == "oldDeviceUnavailable"
    }

    private var shouldShowCircularCountdown: Bool {
        guard let status = engine?.session.status else { return false }
        guard status == .running || status == .paused else { return false }
        return progress?.currentSegment != nil
    }

    private var circularCountdownProgress: CGFloat {
        guard let progress, let segment = progress.currentSegment else { return 0 }
        guard segment.durationSeconds > 0 else { return 0 }
        let ratio = Double(progress.currentSegmentRemainingSeconds) / Double(segment.durationSeconds)
        return CGFloat(min(max(ratio, 0), 1))
    }

    private var circularCountdownTint: Color {
        guard let kind = progress?.currentSegment?.kind else { return .accentColor }
        return Self.segmentTint(for: kind)
    }

    private var pauseResumeTitle: String {
        guard let status = engine?.session.status else { return "Pause" }
        return status == .running ? "Pause" : "Resume"
    }

    private var pauseResumeSystemImage: String {
        guard let status = engine?.session.status else { return "pause.fill" }
        return status == .running ? "pause.fill" : "play.fill"
    }

    private var circularCountdown: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: countdownStrokeWidth)

            Circle()
                .trim(from: 0, to: circularCountdownProgress)
                .stroke(
                    circularCountdownTint,
                    style: StrokeStyle(lineWidth: countdownStrokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: progress?.currentSegmentRemainingSeconds ?? 0)

            Button {
                togglePauseResume()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: pauseResumeSystemImage)
                        .font(.system(size: countdownIconFontSize, weight: .bold))
                    Text(pauseResumeTitle)
                        .font(.headline)
                }
                .frame(width: countdownButtonSize, height: countdownButtonSize)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pauseResumeTitle)
        }
        .frame(width: countdownCircleSize, height: countdownCircleSize)
    }

    private var countdownStrokeWidth: CGFloat {
        isCompactHeight ? 12 : 14
    }

    private var countdownCircleSize: CGFloat {
        isCompactHeight ? 208 : 248
    }

    private var countdownButtonSize: CGFloat {
        isCompactHeight ? 140 : 164
    }

    private var countdownIconFontSize: CGFloat {
        isCompactHeight ? 32 : 38
    }

    private func togglePauseResume() {
        guard var eng = engine else { return }
        let now = Date()
        switch eng.session.status {
        case .running:
            try? eng.pause(reason: .user, at: now)
            SegmentCueNotificationScheduler.cancelAll()
        case .paused:
            try? eng.resume(at: now)
        default:
            break
        }
        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
        persistRecoverableSnapshotIfNeeded(eng, now: now, force: true)
        refreshBackgroundAudioKeepAlive()
    }

    private func endWorkout(confirmed: Bool) {
        guard var eng = engine else { return }
        let now = Date()
        let result = (try? eng.end(at: now, confirmed: confirmed)) ?? .alreadyEnded
        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
        refreshBackgroundAudioKeepAlive()

        switch result {
        case .requiresConfirmation:
            isShowingEndConfirm = true
        case .ended:
            persistSessionIfNeeded(eng.session)
            markCurrentTrainingAsTerminal()
            summaryOutcome = .ended
            summarySession = eng.session
            summaryPresentedForSessionId = eng.session.id
            summaryDismissAction = .clean
            isShowingSummary = true
            cleanupSessionSideEffects()
        case .alreadyEnded:
            break
        case .alreadyCompleted:
            persistSessionIfNeeded(eng.session)
            markCurrentTrainingAsTerminal()
            summaryOutcome = .completed
            summarySession = eng.session
            summaryPresentedForSessionId = eng.session.id
            summaryDismissAction = .clean
            isShowingSummary = true
            cleanupSessionSideEffects()
        }
    }

    private func handleSummaryDismissal() {
        let action = summaryDismissAction
        summaryDismissAction = .clean

        switch action {
        case .restart:
            restartWorkout()
        case .clean:
            if let onExitToCleanTraining {
                onExitToCleanTraining()
            }
        }
    }

    private func restartWorkout() {
        cleanupSessionSideEffects()

        engine = nil
        now = Date()
        isShowingSummary = false
        summaryOutcome = nil
        summarySession = nil
        didPersistSession = false
        isShowingEndConfirm = false
        didConfirmEndFromAlert = false
        lastRecoverableSnapshotPersistedAt = nil
        didTriggerStartPreflight = false
        siriSecondaryAudioSilenceBeganAt = nil
        ignoreRecoverySnapshot = true

        startIfNeeded()
    }

    private func terminateWorkoutForPlanReplacement() {
        guard var eng = engine else {
            cleanupSessionSideEffects {
                NotificationCenter.default.post(name: .interfitCurrentTrainingDidTerminateForReplacement, object: nil)
            }
            return
        }

        let now = Date()
        switch eng.session.status {
        case .running, .paused, .idle:
            _ = try? eng.end(at: now, confirmed: true)
        case .completed, .ended:
            break
        }

        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
        persistSessionIfNeeded(eng.session)
        cleanupSessionSideEffects {
            NotificationCenter.default.post(name: .interfitCurrentTrainingDidTerminateForReplacement, object: nil)
        }

        isShowingSummary = false
        summaryOutcome = nil
        summarySession = nil
        summaryPresentedForSessionId = nil
        isShowingEndConfirm = false
        didConfirmEndFromAlert = false
    }

    private func cleanupSessionSideEffects(onMusicStopped: (() -> Void)? = nil) {
        stopObservingAudioSession()
        nowPlaying.stop()
        SegmentCueNotificationScheduler.cancelAll()
        BackgroundAudioKeepAlive.shared.stop()
        Task { @MainActor in
            await MusicPlaybackClient.stop()
            IdleTimerClient.setDisabled(false)
            onMusicStopped?()
        }
    }

    private func markCurrentTrainingAsTerminal() {
        NotificationCenter.default.post(name: .interfitCurrentTrainingDidReachTerminalState, object: nil)
    }

    private var summaryPlanForSummary: Plan? {
        if let plan { return plan }

        if let snapshot = recoverableSnapshot?.session.planSnapshot {
            return Plan.from(snapshot: snapshot)
        }

        if let session = summarySession ?? engine?.session {
            return Plan.fallbackFrom(session: session)
        }

        return nil
    }

    private func handleRemotePlay() {
        guard var eng = engine else { return }
        let now = Date()
        if eng.session.status == .paused {
            try? eng.resume(at: now)
            engine = eng
            self.now = now
            nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
            persistRecoverableSnapshotIfNeeded(eng, now: now, force: true)
            refreshBackgroundAudioKeepAlive()
        }
    }

    private func handleRemotePause() {
        guard var eng = engine else { return }
        let now = Date()
        if eng.session.status == .running {
            try? eng.pause(reason: .user, at: now)
            engine = eng
            self.now = now
            nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
            persistRecoverableSnapshotIfNeeded(eng, now: now, force: true)
            refreshBackgroundAudioKeepAlive()
        }
    }

    private func handleRemoteToggle() {
        guard let status = engine?.session.status else { return }
        switch status {
        case .running:
            handleRemotePause()
        case .paused:
            handleRemotePlay()
        default:
            break
        }
    }

    private func showBackgroundTimingNoticeIfNeeded() {
        let shouldShow = BackgroundTimingNoticePolicy.shouldShow(
            hasShown: didShowBackgroundTimingNotice,
            isRecovering: recoverableSnapshot != nil
        )
        guard shouldShow else { return }
        didShowBackgroundTimingNotice = true
        isShowingBackgroundTimingNotice = true
    }

    private func scheduleBackgroundSegmentCuesIfNeeded(referenceDate: Date = Date()) {
        guard let eng = engine, eng.session.status == .running else { return }
        let elapsed = eng.progress(at: referenceDate).elapsedSeconds
        SegmentCueNotificationScheduler.schedule(structure: eng.structure, currentElapsed: elapsed)
    }

    private func refreshBackgroundAudioKeepAlive() {
        guard let eng = engine else {
            BackgroundAudioKeepAlive.shared.stop()
            return
        }

        let appState = UIApplication.shared.applicationState
        let shouldKeepAlive = (eng.session.status == .running) && (appState != .active)
        if shouldKeepAlive {
            BackgroundAudioKeepAlive.shared.start()
        } else {
            BackgroundAudioKeepAlive.shared.stop()
        }
    }

    private func simulateHeadphoneDisconnectIfRequested() {
        guard !didSimulateHeadphoneDisconnect else { return }
        guard ProcessInfo.processInfo.arguments.contains("-simulateHeadphoneDisconnect") else { return }
        guard recoverableSnapshot == nil else { return }
        didSimulateHeadphoneDisconnect = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard var eng = engine else { return }
            eng.handleInterruption(.init(kind: .routeChanged, attributes: ["reason": "oldDeviceUnavailable"]))
            engine = eng
            let now = Date()
            self.now = now
            nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
            persistRecoverableSnapshotIfNeeded(eng, now: now, force: true)
        }
    }

    private func persistSessionIfNeeded(_ session: Session) {
        guard !didPersistSession else { return }
        didPersistSession = true
        lastRecoverableSnapshotPersistedAt = nil
        Task { await sessionRepository.upsertSession(session) }
        Task { await recoverableSessionRepository.clearRecoverableSessionSnapshot() }
    }

    private func persistRecoverableSnapshotIfNeeded(_ eng: WorkoutSessionEngine, now: Date, force: Bool = false) {
        guard eng.session.status == .running || eng.session.status == .paused else { return }

        if !force, let lastRecoverableSnapshotPersistedAt, now.timeIntervalSince(lastRecoverableSnapshotPersistedAt) < 5 {
            return
        }

        lastRecoverableSnapshotPersistedAt = now
        let snapshot = eng.recoverableSnapshot(at: now)
        Task { await recoverableSessionRepository.upsertRecoverableSessionSnapshot(snapshot) }
    }

    private func triggerStartPreflightIfNeeded() {
        guard recoverableSnapshot == nil else { return }
        guard !didTriggerStartPreflight else { return }
        didTriggerStartPreflight = true

        Task {
            let report = await WorkoutPreflightRunner.run(name: "startWorkout", timeoutSeconds: 0.8) {
                await gatherStartPreflightAttributes()
            }
            await MainActor.run {
                guard var eng = engine else { return }
                eng.recordPreflight(report, occurredAt: Date())
                engine = eng
            }
        }
    }

    private func gatherStartPreflightAttributes() async -> [String: String] {
        var attributes: [String: String] = [:]

        let audio = AVAudioSession.sharedInstance()
        let outputs = audio.currentRoute.outputs.map { $0.portType.rawValue }
        attributes["audio.outputs"] = outputs.joined(separator: ",")
        attributes["audio.otherAudioPlaying"] = audio.isOtherAudioPlaying ? "true" : "false"
        attributes["audio.secondarySilencedHint"] = audio.secondaryAudioShouldBeSilencedHint ? "true" : "false"

        let networkAttributes = await captureNetworkPathAttributes()
        for (key, value) in networkAttributes {
            attributes[key] = value
        }

        return attributes
    }

    private func captureNetworkPathAttributes() async -> [String: String] {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "interfit.preflight.nwpath")

        let stream = AsyncStream<NWPath> { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path)
                continuation.finish()
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: queue)
        }

        for await path in stream {
            var attributes: [String: String] = [:]
            attributes["network.status"] = String(describing: path.status)
            attributes["network.expensive"] = path.isExpensive ? "true" : "false"
            attributes["network.constrained"] = path.isConstrained ? "true" : "false"
            attributes["network.wifi"] = path.usesInterfaceType(.wifi) ? "true" : "false"
            attributes["network.cellular"] = path.usesInterfaceType(.cellular) ? "true" : "false"
            attributes["network.wiredEthernet"] = path.usesInterfaceType(.wiredEthernet) ? "true" : "false"
            attributes["network.other"] = path.usesInterfaceType(.other) ? "true" : "false"
            return attributes
        }

        return ["network.status": "unknown"]
    }

    private func formatMMSS(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func segmentTint(for kind: WorkoutSegmentKind) -> Color {
        switch kind {
        case .work:
            return .orange
        case .rest:
            return .mint
        }
    }

    private struct TimelineBarSegment: Identifiable {
        let kind: WorkoutSegmentKind
        let setIndex: Int
        let durationSeconds: Int

        var id: String { "\(kind.rawValue)#\(setIndex)" }
    }

    private struct TimelineProgressBar: View {
        let segments: [TimelineBarSegment]
        let progress: Double

        private let segmentSpacing: CGFloat = 2

        private var clampedProgress: CGFloat {
            CGFloat(min(max(progress, 0), 1))
        }

        private var totalDurationSeconds: Int {
            max(1, segments.reduce(0) { $0 + $1.durationSeconds })
        }

        var body: some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                let markerPosition = max(0, min(width, width * clampedProgress))
                let totalSpacing = segmentSpacing * CGFloat(max(segments.count - 1, 0))
                let drawableWidth = max(0, width - totalSpacing)

                ZStack(alignment: .leading) {
                    HStack(spacing: segmentSpacing) {
                        ForEach(segments) { segment in
                            Rectangle()
                                .fill(TrainingView.segmentTint(for: segment.kind))
                                .frame(width: drawableWidth * (CGFloat(segment.durationSeconds) / CGFloat(totalDurationSeconds)))
                        }
                    }

                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: max(0, width - markerPosition))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Capsule()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 4, height: proxy.size.height + 4)
                        .offset(x: max(0, min(width - 4, markerPosition - 2)))
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrainingView()
    }
}
