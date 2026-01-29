import SwiftUI
import Shared

struct SessionTemplateSummaryText: View {
    let session: Session

    private var setsCount: Int { session.effectiveSetsCount }
    private var workSeconds: Int { session.effectiveWorkSeconds }
    private var restSeconds: Int { session.effectiveRestSeconds }

    private var totalSeconds: Int { (workSeconds + restSeconds) * setsCount }

    var body: some View {
        Text("(\(workSeconds)s+\(restSeconds)s) × \(setsCount) = \(totalSeconds)s")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

#Preview {
    SessionTemplateSummaryText(
        session: Session(
            status: .completed,
            startedAt: Date(),
            endedAt: Date(),
            completedSets: 8,
            totalSets: 8,
            workSeconds: 30,
            restSeconds: 15,
            events: [.completed()]
        )
    )
    .padding()
}
