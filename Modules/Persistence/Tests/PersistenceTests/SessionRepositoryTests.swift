import XCTest
import Shared
@testable import Persistence

final class SessionRepositoryTests: XCTestCase {
    func test_coreDataStore_sessionUpsert_persistsAcrossInstances() async {
        let suite = "interfit.persistence.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store1 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let session = Session(
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 160),
            completedSets: 4,
            totalSets: 4,
            workSeconds: 30,
            restSeconds: 10,
            events: [.completed(occurredAt: Date(timeIntervalSince1970: 160))]
        )
        await store1.upsertSession(session)

        let store2 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let fetched = await store2.fetchSession(id: session.id)
        XCTAssertEqual(fetched?.id, session.id)
        XCTAssertEqual(fetched?.status, .completed)

        defaults.removePersistentDomain(forName: suite)
    }
}

