import XCTest
import Shared
@testable import Persistence

final class PlanVersionRepositoryTests: XCTestCase {
    func test_coreDataStore_planVersionCrud_persistsAcrossInstances() async throws {
        let suite = "interfit.persistence.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let planId = UUID()
        let version = PlanVersion(
            planId: planId,
            status: .draft,
            versionNumber: 1,
            setsCount: 3,
            workSeconds: 20,
            restSeconds: 10,
            name: "Draft v1"
        )

        let store1 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        try await store1.upsertPlanVersion(version)
        let fetched1 = await store1.fetchPlanVersions(planId: planId)
        XCTAssertEqual(fetched1.count, 1)

        let store2 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let fetched = await store2.fetchPlanVersions(planId: planId)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, version.id)

        await store2.deletePlanVersion(id: version.id)
        let fetched2 = await store2.fetchPlanVersions(planId: planId)
        XCTAssertEqual(fetched2.count, 0)

        defaults.removePersistentDomain(forName: suite)
    }

    func test_upsertRejectsModifyingPublishedVersion() async throws {
        let store = InMemoryPersistenceStore()
        let planId = UUID()

        let published = PlanVersion(
            planId: planId,
            status: .published,
            versionNumber: 1,
            setsCount: 3,
            workSeconds: 20,
            restSeconds: 10,
            name: "Published v1",
            publishedAt: Date()
        )

        try await store.upsertPlanVersion(published)

        var mutated = published
        mutated.name = "Should be rejected"

        await XCTAssertThrowsErrorAsync {
            try await store.upsertPlanVersion(mutated)
        } verify: { error in
            XCTAssertEqual(error as? PlanVersionRepositoryError, .cannotModifyPublishedVersion)
        }
    }
}

private func XCTAssertThrowsErrorAsync(
    _ operation: @escaping () async throws -> Void,
    verify: (Error) -> Void = { _ in }
) async {
    do {
        try await operation()
        XCTFail("Expected error but succeeded")
    } catch {
        verify(error)
    }
}
