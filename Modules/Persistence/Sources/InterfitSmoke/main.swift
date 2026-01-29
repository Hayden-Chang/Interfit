import Foundation
import Persistence
import Shared

@main
struct InterfitSmokeMain {
    static func main() async {
        do {
            try await run()
            print("INTERFIT_SMOKE: PASS")
            exit(0)
        } catch {
            fputs("INTERFIT_SMOKE: FAIL: \(error)\n", stderr)
            exit(1)
        }
    }

    static func run() async throws {
        let suite = "interfit.smoke.\(UUID().uuidString)"
        let store = CoreDataPersistenceStore(userDefaultsSuiteName: suite)

        try await runCoreSmoke(store: store)
        try await runDebugHelpersSmoke(suite: suite, store: store)
    }

    static func runCoreSmoke(store: CoreDataPersistenceStore) async throws {
        let plans: any PlanRepository = store
        let sessions: any SessionRepository = store

        let basePlan = Plan(setsCount: 1, workSeconds: 10, restSeconds: 0, name: "Smoke Plan")
        await plans.upsertPlan(basePlan)

        let fetchedPlans1 = await plans.fetchAllPlans()
        guard fetchedPlans1.contains(where: { $0.id == basePlan.id }) else {
            throw SmokeError.missingPlan
        }

        let copied = await plans.duplicatePlan(id: basePlan.id, nameOverride: nil)
        guard let copied else { throw SmokeError.duplicateFailed }

        let fetchedPlans2 = await plans.fetchAllPlans()
        guard fetchedPlans2.contains(where: { $0.id == copied.id }) else {
            throw SmokeError.missingCopiedPlan
        }

        await plans.deletePlan(id: basePlan.id)
        let fetchedPlans3 = await plans.fetchAllPlans()
        guard !fetchedPlans3.contains(where: { $0.id == basePlan.id }) else {
            throw SmokeError.deleteFailed
        }

        var engine = try WorkoutSessionEngine(plan: copied, now: Date(timeIntervalSince1970: 0))
        _ = engine.tick(at: Date(timeIntervalSince1970: 11))

        let session = engine.session
        guard session.status == .completed else { throw SmokeError.sessionNotCompleted }

        await sessions.upsertSession(session)
        let fetchedSessions1 = await sessions.fetchAllSessions()
        guard fetchedSessions1.contains(where: { $0.id == session.id }) else {
            throw SmokeError.missingSession
        }

        let fetchedSession = await sessions.fetchSession(id: session.id)
        guard let fetchedSession else { throw SmokeError.missingSession }
        guard fetchedSession.events.contains(where: { $0.kind == .completed }) else {
            throw SmokeError.missingCompletedEvent
        }
    }

    static func runDebugHelpersSmoke(suite: String, store: CoreDataPersistenceStore) async throws {
#if DEBUG
        let defaults = UserDefaults(suiteName: suite)
        guard let defaults else { throw SmokeError.userDefaultsUnavailable }

        let plans: any PlanRepository = store
        let sessions: any SessionRepository = store

        // reset
        defaults.removeObject(forKey: "interfit.demoData.seeded")
        defaults.removeObject(forKey: "interfit.autoSmokeFlow.seeded")
        await store.resetAllData()

        guard (await plans.fetchAllPlans()).isEmpty else { throw SmokeError.debugResetNotEmpty }
        guard (await sessions.fetchAllSessions()).isEmpty else { throw SmokeError.debugResetNotEmpty }

        // seed demo data (equivalent to Debug menu "Seed demo data")
        do {
            let seededKey = "interfit.demoData.seeded"
            guard !defaults.bool(forKey: seededKey) else { throw SmokeError.debugSeedUnexpectedAlreadySeeded }

            let plan = Plan(setsCount: 6, workSeconds: 30, restSeconds: 15, name: "Demo HIIT")
            await plans.upsertPlan(plan)

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
            await sessions.upsertSession(session)

            defaults.set(true, forKey: seededKey)
        }

        guard (await plans.fetchAllPlans()).contains(where: { $0.name == "Demo HIIT" }) else {
            throw SmokeError.debugSeedDemoMissingPlan
        }
        guard (await sessions.fetchAllSessions()).contains(where: { $0.events.contains(where: { $0.kind == .completed }) }) else {
            throw SmokeError.debugSeedDemoMissingSession
        }

        // reset again
        defaults.removeObject(forKey: "interfit.demoData.seeded")
        defaults.removeObject(forKey: "interfit.autoSmokeFlow.seeded")
        await store.resetAllData()
        guard (await plans.fetchAllPlans()).isEmpty else { throw SmokeError.debugResetNotEmpty }
        guard (await sessions.fetchAllSessions()).isEmpty else { throw SmokeError.debugResetNotEmpty }

        // seed smoke flow (equivalent to Debug menu "Seed smoke flow")
        do {
            let seededKey = "interfit.autoSmokeFlow.seeded"
            guard !defaults.bool(forKey: seededKey) else { throw SmokeError.debugSeedUnexpectedAlreadySeeded }

            let plan = Plan(setsCount: 2, workSeconds: 10, restSeconds: 0, name: "SmokeFlow Plan")
            await plans.upsertPlan(plan)

            var engine = try? WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))
            _ = engine?.tick(at: Date(timeIntervalSince1970: 25))
            if let session = engine?.session {
                await sessions.upsertSession(session)
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
            await plans.upsertPlan(saved)

            defaults.set(true, forKey: seededKey)
        }

        let plansAfter = await plans.fetchAllPlans()
        guard plansAfter.filter({ $0.name == "SmokeFlow Plan" }).count >= 2 else {
            throw SmokeError.debugSeedSmokeMissingPlans
        }
        guard !(await sessions.fetchAllSessions()).isEmpty else {
            throw SmokeError.debugSeedSmokeMissingSession
        }
#else
        _ = suite
        _ = store
#endif
    }
}

enum SmokeError: Error {
    case missingPlan
    case duplicateFailed
    case missingCopiedPlan
    case deleteFailed
    case sessionNotCompleted
    case missingSession
    case missingCompletedEvent
    case userDefaultsUnavailable
    case debugResetNotEmpty
    case debugSeedUnexpectedAlreadySeeded
    case debugSeedDemoMissingPlan
    case debugSeedDemoMissingSession
    case debugSeedSmokeMissingPlans
    case debugSeedSmokeMissingSession
}
