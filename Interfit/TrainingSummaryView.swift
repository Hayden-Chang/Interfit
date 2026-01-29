import SwiftUI
import Shared
import Persistence

struct TrainingSummaryView: View {
    enum Outcome: String, Sendable {
        case completed
        case ended
    }

    let outcome: Outcome
    let plan: Plan
    let session: Session?

    @Environment(\.dismiss) private var dismiss
    @State private var didSaveToPlans: Bool = false

    private let planRepository: any PlanRepository = CoreDataPersistenceStore()

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.title2.bold())

            VStack(spacing: 6) {
                Text(plan.name)
                    .font(.headline)
                PlanTemplateSummaryText(plan: plan)
            }
            .foregroundStyle(.secondary)

            if session?.hasOverrides == true {
                Text("Temporary adjustments were applied for this workout (not saved back to the plan).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer().frame(height: 8)

            Button("Train Again") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Save to Plans") {
                saveToPlans()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Summary")
        .alert("Saved", isPresented: $didSaveToPlans) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Plan saved to Plans.")
        }
    }

    private var title: String {
        switch outcome {
        case .completed:
            "Workout complete"
        case .ended:
            "Workout ended early"
        }
    }

    private func saveToPlans() {
        let now = Date()
        let snapshot = Plan(
            id: UUID(),
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name,
            isFavorite: false,
            createdAt: now,
            updatedAt: now
        )
        Task {
            await planRepository.upsertPlan(snapshot)
            await MainActor.run { didSaveToPlans = true }
        }
    }
}

#Preview {
    NavigationStack {
        TrainingSummaryView(
            outcome: .completed,
            plan: Plan(setsCount: 8, workSeconds: 30, restSeconds: 15, name: "HIIT"),
            session: nil
        )
    }
}
