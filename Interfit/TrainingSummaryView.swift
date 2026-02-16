import SwiftUI
import Shared

struct TrainingSummaryView: View {
    enum Outcome: String, Sendable {
        case completed
        case ended
    }

    let outcome: Outcome
    let plan: Plan
    let session: Session?
    let onTrainAgain: () -> Void

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
                onTrainAgain()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Summary")
    }

    private var title: String {
        switch outcome {
        case .completed:
            "Workout complete"
        case .ended:
            "Workout ended early"
        }
    }

}

#Preview {
    NavigationStack {
        TrainingSummaryView(
            outcome: .completed,
            plan: Plan(setsCount: 8, workSeconds: 30, restSeconds: 15, name: "HIIT"),
            session: nil
            ,
            onTrainAgain: {}
        )
    }
}
