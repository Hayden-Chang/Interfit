import SwiftUI
import Shared
import Persistence
import Audio
import AVFoundation
import Network

struct TrainingView: View {
    let plan: Plan?
    let recoverableSnapshot: RecoverableSessionSnapshot?

    @State private var engine: WorkoutSessionEngine?
    @State private var now: Date = Date()
    @StateObject private var nowPlaying = NowPlayingManager()

    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize: CGFloat = 72

    @State private var isShowingSummary: Bool = false
    @State private var summaryOutcome: TrainingSummaryView.Outcome?
    @State private var summarySession: Session?
    @State private var isShowingEndConfirm: Bool = false
    @State private var didPersistSession: Bool = false
    @State private var isShowingMusicPicker: Bool = false
    @State private var isShowingBackgroundTimingNotice: Bool = false
    @State private var audioSessionObservation: AudioSessionObservationToken?
    @State private var lastRecoverableSnapshotPersistedAt: Date?
    @State private var didTriggerStartPreflight: Bool = false
    @State private var didSimulateHeadphoneDisconnect: Bool = false

    @AppStorage(BackgroundTimingNoticePolicy.userDefaultsKey) private var didShowBackgroundTimingNotice: Bool = false

    private let persistenceStore = CoreDataPersistenceStore()
    private var sessionRepository: any SessionRepository { persistenceStore }
    private var recoverableSessionRepository: any RecoverableSessionRepository { persistenceStore }

    private let tickTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(plan: Plan? = nil, recoverableSnapshot: RecoverableSessionSnapshot? = nil) {
        self.plan = plan
        self.recoverableSnapshot = recoverableSnapshot
    }

    var body: some View {
        VStack(spacing: 16) {
            if let plan {
                Text(plan.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(segmentTitle)
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(formattedCountdown)
                .font(.system(size: countdownFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(setProgressText)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSafetyPausedByHeadphoneDisconnect {
                Text("Paused for safety (headphones disconnected). Tap Resume to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Button(primaryButtonTitle) {
                togglePauseResume()
            }
            .buttonStyle(.borderedProminent)
            .disabled(engine == nil || engine?.session.status == .completed || engine?.session.status == .ended)

            if isRestSegment {
                Button("Add music") {
                    isShowingMusicPicker = true
                }
                .buttonStyle(.bordered)
                .disabled(engine == nil || engine?.session.status != .running)
            }
        }
        .padding()
        .navigationTitle("Training")
        .onAppear { startIfNeeded() }
        .onDisappear {
            stopObservingAudioSession()
            nowPlaying.stop()
        }
        .onReceive(tickTimer) { now in tickIfNeeded(now: now) }
        .onReceive(NotificationCenter.default.publisher(for: NowPlayingManager.remotePlayNotification)) { _ in
            handleRemotePlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: NowPlayingManager.remotePauseNotification)) { _ in
            handleRemotePause()
        }
        .onReceive(NotificationCenter.default.publisher(for: NowPlayingManager.remoteToggleNotification)) { _ in
            handleRemoteToggle()
        }
        .navigationDestination(isPresented: $isShowingSummary) {
            if let plan, let summaryOutcome {
                TrainingSummaryView(outcome: summaryOutcome, plan: plan, session: summarySession)
            }
        }
        .sheet(isPresented: $isShowingMusicPicker) {
            NavigationStack {
                MusicPickerView { selection in
                    applyMusicOverride(selection)
                }
            }
        }
        .alert("End workout?", isPresented: $isShowingEndConfirm) {
            Button("End", role: .destructive) { endWorkout(confirmed: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the workout and show a summary.")
        }
        .alert(BackgroundTimingNoticePolicy.title, isPresented: $isShowingBackgroundTimingNotice) {
            Button("Continue", role: .cancel) {}
            Button("Add music") { isShowingMusicPicker = true }
        } message: {
            Text(BackgroundTimingNoticePolicy.message)
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

    private func startIfNeeded() {
        guard engine == nil else { return }
        let sinks: [CueSink] = [
            AudioCueSink(enabled: true),
            HapticsCueSink(enabled: true),
        ]
        let cues = CueCoalescingSink(MultiCueSink(sinks))

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
                return nil
            },
            selectionApplier: { _ in
                if simulatePlaybackLoadFailure {
                    struct SimulatedPlaybackLoadError: Error {}
                    throw SimulatedPlaybackLoadError()
                }
            },
            failureClassifier: { _ in
                simulatePlaybackLoadFailure ? .timeout : .unknown
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
            }
        })
        if let recoverableSnapshot {
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
        showBackgroundTimingNoticeIfNeeded()
        simulateHeadphoneDisconnectIfRequested()
    }

    private func tickIfNeeded(now: Date) {
        guard var eng = engine else { return }
        _ = eng.tick(at: now)
        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
        persistRecoverableSnapshotIfNeeded(eng, now: now)

        if !isShowingSummary {
            switch eng.session.status {
            case .completed:
                persistSessionIfNeeded(eng.session)
                summaryOutcome = .completed
                summarySession = eng.session
                isShowingSummary = true
                nowPlaying.stop()
            case .ended:
                persistSessionIfNeeded(eng.session)
                summaryOutcome = .ended
                summarySession = eng.session
                isShowingSummary = true
                nowPlaying.stop()
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

    private var isRestSegment: Bool {
        progress?.currentSegment?.kind == .rest
    }

    private func applyMusicOverride(_ selection: MusicSelection) {
        guard var eng = engine else { return }
        eng.setMusicSelectionOverride(selection, at: now)
        engine = eng
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

    private var formattedCountdown: String {
        guard let progress else { return "00:00" }
        let seconds = progress.currentSegmentRemainingSeconds
        return formatMMSS(seconds)
    }

    private var setProgressText: String {
        guard let progress else { return "0 / 0 sets" }
        if let seg = progress.currentSegment {
            return "\(seg.setIndex) / \(progress.totalSets) sets"
        }
        return "\(progress.totalSets) / \(progress.totalSets) sets"
    }

    private var primaryButtonTitle: String {
        guard let engine else { return "Start" }
        switch engine.session.status {
        case .running: return "Pause"
        case .paused: return "Resume"
        case .idle: return "Start"
        case .completed, .ended: return "Done"
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

    private func togglePauseResume() {
        guard var eng = engine else { return }
        let now = Date()
        switch eng.session.status {
        case .running:
            try? eng.pause(reason: .user, at: now)
        case .paused:
            try? eng.resume(at: now)
        default:
            break
        }
        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)
        persistRecoverableSnapshotIfNeeded(eng, now: now, force: true)
    }

    private func endWorkout(confirmed: Bool) {
        guard var eng = engine else { return }
        let now = Date()
        let result = (try? eng.end(at: now, confirmed: confirmed)) ?? .alreadyEnded
        engine = eng
        self.now = now
        nowPlaying.update(planName: plan?.name, progress: eng.progress(at: now), sessionStatus: eng.session.status)

        switch result {
        case .requiresConfirmation:
            isShowingEndConfirm = true
        case .ended:
            persistSessionIfNeeded(eng.session)
            summaryOutcome = .ended
            isShowingSummary = true
            nowPlaying.stop()
        case .alreadyEnded:
            break
        case .alreadyCompleted:
            persistSessionIfNeeded(eng.session)
            summaryOutcome = .completed
            isShowingSummary = true
            nowPlaying.stop()
        }
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
}

#Preview {
    NavigationStack {
        TrainingView()
    }
}
