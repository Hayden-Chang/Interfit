import SwiftUI
import Persistence
import Shared

struct RootTabView: View {
    private enum Tab: Hashable {
        case train
        case training
        case me
    }

    @State private var pendingRecovery: PendingRecoverySnapshot?
    @State private var isShowingRecoveredTraining: Bool = false
    @State private var recoveredTrainingSnapshot: RecoverableSessionSnapshot?
    @State private var recoveredTrainingPlan: Plan?
    @State private var selectedTab: Tab = .train
    @State private var trainingPlan: Plan?
    @State private var pendingPlanToStart: Plan?
    @State private var isShowingReplaceTrainingConfirm: Bool = false
    @State private var isCurrentTrainingTerminalState: Bool = false
    @State private var trainingNavigationResetToken: UUID = UUID()

    @AppStorage("interfit.analytics.optIn") private var isAnalyticsOptIn: Bool = true

    private let persistenceStore = CoreDataPersistenceStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                QuickStartView(onStart: startTrainingFromTrainTab(plan:))
            }
            .tabItem {
                Label("Train", systemImage: "figure.run")
            }
            .tag(Tab.train)

            NavigationStack {
                TrainingView(
                    plan: trainingPlan,
                    onExitToCleanTraining: {
                        trainingPlan = nil
                        isCurrentTrainingTerminalState = false
                    }
                )
                    .id(trainingRoute)
            }
            .id(trainingNavigationResetToken)
            .tabItem {
                Label("Training", systemImage: "stopwatch")
            }
            .tag(Tab.training)

            NavigationStack {
                List {
                    Section {
                        NavigationLink {
                            SessionHistoryListView()
                        } label: {
                            Text("History")
                        }
                    }

                    Section("Audio") {
                        let threshold = Binding<Double>(
                            get: { SiriInterruptionSettingsStore.pauseThresholdSeconds },
                            set: { SiriInterruptionSettingsStore.pauseThresholdSeconds = $0 }
                        )
                        Stepper(value: threshold, in: 0...10, step: 0.5) {
                            Text("Siri pause threshold: \(threshold.wrappedValue, specifier: "%.1f")s")
                        }
                        Text("If Siri silences your audio briefly, InterBeat won’t pause the workout unless it lasts longer than this threshold.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Privacy") {
                        Toggle("Allow anonymous usage data", isOn: $isAnalyticsOptIn)
                        if let privacyPolicyURL = URL(string: "https://hayden-chang.github.io/support/privacy-policies/interfit/privacy-policy.html") {
                            Link("Privacy Policy", destination: privacyPolicyURL)
                        }
                        Text("Turn off to stop recording analytics events. Training and local history are not affected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

#if DEBUG
                    Section("Debug") {
                        NavigationLink {
                            DebugMenuView()
                        } label: {
                            Text("Debug Menu")
                        }
                    }
#endif
                }
                .navigationTitle("Me")
            }
            .tabItem {
                Label("Me", systemImage: "person")
            }
            .tag(Tab.me)
        }
        .task {
#if DEBUG
            await DemoDataSeeder.resetIfRequested()
            await DemoDataSeeder.seedIfRequested()
            await SmokeFlowSeeder.seedIfRequested()
            await AutoAcceptanceRunner.runIfNeeded()
#endif
            await AnalyticsEventRecorder.shared.recordAppOpen()
            await checkForRecoverableSessionSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .interfitCurrentTrainingDidTerminateForReplacement)) { _ in
            startPendingPlanAfterTermination()
        }
        .onReceive(NotificationCenter.default.publisher(for: .interfitCurrentTrainingDidReachTerminalState)) { _ in
            isCurrentTrainingTerminalState = true
        }
        .sheet(item: $pendingRecovery) { pending in
            RecoveryDecisionView(
                snapshot: pending.snapshot,
                onContinue: { continueRecovery(with: pending.snapshot) },
                onEndAndSave: { endAndSaveRecovery(pending.snapshot) },
                onDiscard: { discardRecovery(pending.snapshot) }
            )
        }
        .fullScreenCover(isPresented: $isShowingRecoveredTraining) {
            if let recoveredTrainingSnapshot {
                NavigationStack {
                    TrainingView(plan: recoveredTrainingPlan, recoverableSnapshot: recoveredTrainingSnapshot)
                }
            }
        }
        .alert("End current training?", isPresented: $isShowingReplaceTrainingConfirm) {
            Button("End and Start New", role: .destructive) {
                confirmReplaceTrainingAndStartPendingPlan()
            }
            Button("Cancel", role: .cancel) {
                pendingPlanToStart = nil
            }
        } message: {
            Text("A training session is currently active. End it and stop music before starting the new plan?")
        }
    }

    private var trainingRoute: AnyHashable {
        if let trainingPlan {
            return AnyHashable(trainingPlan.id)
        }
        return AnyHashable("training.none")
    }

    private func startTrainingFromTrainTab(plan: Plan) {
        if shouldConfirmReplacingCurrentTraining(with: plan) {
            pendingPlanToStart = plan
            isShowingReplaceTrainingConfirm = true
            return
        }

        isCurrentTrainingTerminalState = false
        trainingNavigationResetToken = UUID()
        trainingPlan = plan
        selectedTab = .training
    }

    private func shouldConfirmReplacingCurrentTraining(with _: Plan) -> Bool {
        guard trainingPlan != nil else { return false }
        guard !isCurrentTrainingTerminalState else { return false }
        return true
    }

    private func confirmReplaceTrainingAndStartPendingPlan() {
        guard pendingPlanToStart != nil else { return }
        NotificationCenter.default.post(name: .interfitTerminateCurrentTrainingForReplacement, object: nil)
    }

    private func startPendingPlanAfterTermination() {
        guard let pendingPlanToStart else { return }
        isCurrentTrainingTerminalState = false
        trainingNavigationResetToken = UUID()
        trainingPlan = pendingPlanToStart
        selectedTab = .training
        self.pendingPlanToStart = nil
    }

    private func checkForRecoverableSessionSnapshot() async {
        guard pendingRecovery == nil else { return }
        guard recoveredTrainingSnapshot == nil else { return }

        if let snapshot = await persistenceStore.fetchRecoverableSessionSnapshot() {
            await MainActor.run {
                pendingRecovery = PendingRecoverySnapshot(snapshot: snapshot)
            }
        }
    }

    private func continueRecovery(with snapshot: RecoverableSessionSnapshot) {
        let planSnapshot = snapshot.session.planSnapshot
        recoveredTrainingPlan = planSnapshot.map {
            Plan(
                id: $0.planId ?? UUID(),
                setsCount: $0.setsCount,
                workSeconds: $0.workSeconds,
                restSeconds: $0.restSeconds,
                name: $0.name,
                musicStrategy: $0.musicStrategy,
                createdAt: $0.capturedAt,
                updatedAt: $0.capturedAt
            )
        }
        recoveredTrainingSnapshot = snapshot
        pendingRecovery = nil
        isShowingRecoveredTraining = true
    }

    private func endAndSaveRecovery(_ snapshot: RecoverableSessionSnapshot) {
        Task {
            var session = snapshot.session
            let now = Date()
            session.status = .ended
            session.endedAt = now
            session.events.append(.ended(occurredAt: now))
            await persistenceStore.upsertSession(session)
            await persistenceStore.clearRecoverableSessionSnapshot()
            await MainActor.run {
                pendingRecovery = nil
            }
        }
    }

    private func discardRecovery(_ snapshot: RecoverableSessionSnapshot) {
        Task {
            await persistenceStore.clearRecoverableSessionSnapshot()
            await MainActor.run {
                pendingRecovery = nil
            }
        }
    }
}

private struct PendingRecoverySnapshot: Identifiable {
    let snapshot: RecoverableSessionSnapshot

    var id: UUID { snapshot.session.id }
}

#Preview {
    RootTabView()
}
