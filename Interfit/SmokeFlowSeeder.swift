import Foundation
import Persistence
import Shared

enum SmokeFlowSeeder {
    private static let seededKey = "interfit.autoSmokeFlow.seeded"

    /// Seeds data that approximates a full UI flow:
    /// - create a plan (as if from Plans/QuickStart)
    /// - run a session to completion and persist it (as if Training ended)
    /// - save a snapshot plan (as if Summary "Save to Plans")
    static func seedIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) async {
#if DEBUG
        guard arguments.contains("-autoSmokeFlow") else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }

        let store = CoreDataPersistenceStore()
        let planRepo: any PlanRepository = store
        let sessionRepo: any SessionRepository = store

        let plan = Plan(setsCount: 2, workSeconds: 10, restSeconds: 0, name: "SmokeFlow Plan")
        await planRepo.upsertPlan(plan)

        var engine = try? WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))
        _ = engine?.tick(at: Date(timeIntervalSince1970: 25))
        if let session = engine?.session {
            await sessionRepo.upsertSession(session)
        }

        let now = Date()
        let saved = Plan(
            id: UUID(),
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name,
            isFavorite: false,
            createdAt: now,
            updatedAt: now
        )
        await planRepo.upsertPlan(saved)

        defaults.set(true, forKey: seededKey)
#else
        _ = arguments
#endif
    }
}
