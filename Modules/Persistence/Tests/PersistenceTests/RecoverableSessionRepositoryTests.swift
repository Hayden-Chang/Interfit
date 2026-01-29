import XCTest
import Shared
@testable import Persistence

final class RecoverableSessionRepositoryTests: XCTestCase {
    func test_coreDataStore_recoverableSnapshot_persistsAcrossInstances_andCanClear() async {
        let suite = "interfit.persistence.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store1 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let session = Session(
            status: .paused,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            completedSets: 1,
            totalSets: 4,
            workSeconds: 30,
            restSeconds: 10,
            events: [.paused(occurredAt: Date(timeIntervalSince1970: 120), reason: PauseReason.safety.rawValue)]
        )
        let snapshot = RecoverableSessionSnapshot(
            session: session,
            elapsedSeconds: 42,
            capturedAt: Date(timeIntervalSince1970: 123)
        )
        await store1.upsertRecoverableSessionSnapshot(snapshot)

        let store2 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let fetched = await store2.fetchRecoverableSessionSnapshot()
        XCTAssertEqual(fetched, snapshot)

        await store2.clearRecoverableSessionSnapshot()
        let store3 = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let cleared = await store3.fetchRecoverableSessionSnapshot()
        XCTAssertNil(cleared)

        defaults.removePersistentDomain(forName: suite)
    }

    func test_coreDataStore_corruptedRecoverableSnapshot_isCleared_andMarkerIsRecorded() async {
        let suite = "interfit.persistence.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let snapshotKey = "interfit.persistence.recoverableSessionSnapshot"
        let decodeFailedAtKey = "interfit.persistence.recoverableSessionSnapshot.decodeFailedAt"
        let decodeFailedBytesKey = "interfit.persistence.recoverableSessionSnapshot.decodeFailedBytes"

        defaults.set(Data([0x01, 0x02, 0x03, 0x04, 0x05]), forKey: snapshotKey)

        let store = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        let fetched = await store.fetchRecoverableSessionSnapshot()
        XCTAssertNil(fetched)

        XCTAssertNil(defaults.data(forKey: snapshotKey))
        XCTAssertNotNil(defaults.object(forKey: decodeFailedAtKey) as? Date)
        XCTAssertEqual(defaults.object(forKey: decodeFailedBytesKey) as? Int, 5)

        defaults.removePersistentDomain(forName: suite)
    }
}
