import SwiftUI
import Shared

struct RecoveryDecisionView: View {
    let snapshot: RecoverableSessionSnapshot
    let onContinue: () -> Void
    let onEndAndSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Resume workout?")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.session.planSnapshot?.name ?? "Workout")
                    .font(.headline)
                Text("Elapsed: \(formatMMSS(snapshot.elapsedSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)

            Button("End & Save") { onEndAndSave() }
                .buttonStyle(.bordered)

            Button("Discard") { onDiscard() }
                .buttonStyle(.bordered)
                .tint(.red)
        }
        .padding()
    }

    private func formatMMSS(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    RecoveryDecisionView(
        snapshot: RecoverableSessionSnapshot(
            session: Session(
                status: .paused,
                startedAt: Date(),
                endedAt: nil,
                planSnapshot: PlanSnapshot(planId: nil, setsCount: 4, workSeconds: 30, restSeconds: 10, name: "Demo", capturedAt: Date()),
                completedSets: 1,
                totalSets: 4,
                workSeconds: 30,
                restSeconds: 10,
                events: []
            ),
            elapsedSeconds: 95
        ),
        onContinue: {},
        onEndAndSave: {},
        onDiscard: {}
    )
}

