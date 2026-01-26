import XCTest
import Shared
@testable import Persistence

final class PlanRepositoryTests: XCTestCase {
    func test_coreDataStore_planCrud_persistsAcrossInstances() async {
        let suite = "interfit.persistence.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store1 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let plan = Plan(setsCount: 3, workSeconds: 20, restSeconds: 10, name: "A")
        await store1.upsertPlan(plan)
        let all1 = await store1.fetchAllPlans()
        XCTAssertEqual(all1.count, 1)

        // "Restart": new store instance, same backing defaults.
        let store2 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let all = await store2.fetchAllPlans()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, plan.id)

        await store2.deletePlan(id: plan.id)
        let all2 = await store2.fetchAllPlans()
        XCTAssertEqual(all2.count, 0)

        defaults.removePersistentDomain(forName: suite)
    }

    func test_duplicate_createsNewId() async {
        let store = InMemoryPersistenceStore()
        let plan = Plan(setsCount: 2, workSeconds: 30, restSeconds: 0, name: "Base")
        await store.upsertPlan(plan)

        let copy = await store.duplicatePlan(id: plan.id, nameOverride: nil)
        XCTAssertNotNil(copy)
        XCTAssertNotEqual(copy?.id, plan.id)
        XCTAssertEqual(copy?.setsCount, plan.setsCount)
    }
}

