import Foundation
import Persistence
import Shared

enum DemoDataSeeder {
    private static let seededKey = "interfit.demoData.seeded"

    static func seedIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) async {
#if DEBUG
        guard arguments.contains("-seedDemoData") else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }

        let store = CoreDataPersistenceStore()
        let planRepo: any PlanRepository = store
        let sessionRepo: any SessionRepository = store

        let plan = Plan(setsCount: 6, workSeconds: 30, restSeconds: 15, name: "Demo HIIT")
        await planRepo.upsertPlan(plan)

        let base = Date().addingTimeInterval(-30 * 60)
        let session = Session(
            status: .completed,
            startedAt: base,
            endedAt: base.addingTimeInterval(TimeInterval(plan.estimatedTotalSeconds)),
            completedSets: plan.setsCount,
            totalSets: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            events: [
                .segmentChanged(occurredAt: base.addingTimeInterval(30), from: nil, to: "work#1"),
                .paused(occurredAt: base.addingTimeInterval(75), reason: "user"),
                .resumed(occurredAt: base.addingTimeInterval(90)),
                .completed(occurredAt: base.addingTimeInterval(TimeInterval(plan.estimatedTotalSeconds))),
            ]
        )
        await sessionRepo.upsertSession(session)

        defaults.set(true, forKey: seededKey)
#else
        _ = arguments
#endif
    }

    static func resetIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) async {
#if DEBUG
        guard arguments.contains("-resetDemoData") else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: seededKey)
        defaults.removeObject(forKey: "interfit.autoSmokeFlow.seeded")

        let store = CoreDataPersistenceStore()
        await store.resetAllData()
#else
        _ = arguments
#endif
    }
}
