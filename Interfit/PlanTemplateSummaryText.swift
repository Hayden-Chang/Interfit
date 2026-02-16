import SwiftUI
import Shared

struct PlanTemplateSummaryText: View {
    let plan: Plan

    private var totalSeconds: Int {
        (plan.workSeconds + plan.restSeconds) * plan.setsCount
    }

    private var formattedTotalDuration: String {
        let total = max(0, totalSeconds)
        let h = total / 3600
        let min = (total % 3600) / 60
        let s = total % 60

        var parts: [String] = []
        if h > 0 {
            parts.append("\(h)h")
            parts.append("\(min)min")
        } else if min > 0 {
            parts.append("\(min)min")
        }
        parts.append("\(s)s")
        return parts.joined(separator: " ")
    }

    var body: some View {
        Text("(\(plan.workSeconds)s+\(plan.restSeconds)s) × \(plan.setsCount) = \(formattedTotalDuration)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

#Preview {
    PlanTemplateSummaryText(plan: Plan(setsCount: 8, workSeconds: 30, restSeconds: 15, name: "HIIT"))
        .padding()
}
