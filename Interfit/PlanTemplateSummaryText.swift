import SwiftUI
import Shared

struct PlanTemplateSummaryText: View {
    let plan: Plan

    private var totalSeconds: Int {
        (plan.workSeconds + plan.restSeconds) * plan.setsCount
    }

    var body: some View {
        Text("(\(plan.workSeconds)s+\(plan.restSeconds)s) × \(plan.setsCount) = \(totalSeconds)s")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

#Preview {
    PlanTemplateSummaryText(plan: Plan(setsCount: 8, workSeconds: 30, restSeconds: 15, name: "HIIT"))
        .padding()
}
