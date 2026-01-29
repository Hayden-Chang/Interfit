import SwiftUI
import Persistence
import Shared

struct RootTabView: View {
    @State private var pendingRecoverySnapshot: RecoverableSessionSnapshot?
    @State private var isShowingRecoveryDecision: Bool = false
    @State private var isShowingRecoveredTraining: Bool = false
    @State private var recoveredTrainingSnapshot: RecoverableSessionSnapshot?
    @State private var recoveredTrainingPlan: Plan?

    @AppStorage("interfit.analytics.optIn") private var isAnalyticsOptIn: Bool = true

    private let persistenceStore = CoreDataPersistenceStore()

    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section {
                        NavigationLink {
                            QuickStartView()
                        } label: {
                            Text("Quick Start")
                        }

                        NavigationLink {
                            TrainingView()
                        } label: {
                            Text("Training")
                        }
                    }
                }
                .navigationTitle("Train")
            }
            .tabItem {
                Label("Train", systemImage: "figure.run")
            }

            NavigationStack {
                PlansListView()
            }
            .tabItem {
                Label("Plans", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                CommunityFeedView()
            }
            .tabItem {
                Label("Community", systemImage: "globe")
            }

            NavigationStack {
                List {
                    Section {
                        NavigationLink {
                            SessionHistoryListView()
                        } label: {
                            Text("History")
                        }
                    }

                    Section("Privacy") {
                        Toggle("Allow anonymous usage data", isOn: $isAnalyticsOptIn)
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
        }
        .task {
#if DEBUG
            await AutoAcceptanceRunner.runIfNeeded()
#endif
            await AnalyticsEventRecorder.shared.recordAppOpen()
            await checkForRecoverableSessionSnapshot()
        }
        .sheet(isPresented: $isShowingRecoveryDecision) {
            if let pendingRecoverySnapshot {
                RecoveryDecisionView(
                    snapshot: pendingRecoverySnapshot,
                    onContinue: { continueRecovery(with: pendingRecoverySnapshot) },
                    onEndAndSave: { endAndSaveRecovery(pendingRecoverySnapshot) },
                    onDiscard: { discardRecovery(pendingRecoverySnapshot) }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingRecoveredTraining) {
            if let recoveredTrainingSnapshot {
                NavigationStack {
                    TrainingView(plan: recoveredTrainingPlan, recoverableSnapshot: recoveredTrainingSnapshot)
                }
            }
        }
    }

    private func checkForRecoverableSessionSnapshot() async {
        guard pendingRecoverySnapshot == nil else { return }
        guard recoveredTrainingSnapshot == nil else { return }

        if let snapshot = await persistenceStore.fetchRecoverableSessionSnapshot() {
            await MainActor.run {
                pendingRecoverySnapshot = snapshot
                isShowingRecoveryDecision = true
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
                createdAt: $0.capturedAt,
                updatedAt: $0.capturedAt
            )
        }
        recoveredTrainingSnapshot = snapshot
        pendingRecoverySnapshot = nil
        isShowingRecoveryDecision = false
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
                pendingRecoverySnapshot = nil
                isShowingRecoveryDecision = false
            }
        }
    }

    private func discardRecovery(_ snapshot: RecoverableSessionSnapshot) {
        Task {
            await persistenceStore.clearRecoverableSessionSnapshot()
            await MainActor.run {
                pendingRecoverySnapshot = nil
                isShowingRecoveryDecision = false
            }
        }
    }
}

#Preview {
    RootTabView()
}
