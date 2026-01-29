import Shared
import XCTest
@testable import Persistence

final class BackupBundleTests: XCTestCase {
    func test_backupBundle_roundTrip_overwrite() async throws {
        let suite = "interfit.tests.backup.\(UUID().uuidString)"
        let store = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        await store.resetAllData()
        await store.writeStoredSchemaVersion(PersistenceSchemaVersion.current)

        let plan = Plan(setsCount: 2, workSeconds: 10, restSeconds: 0, name: "Backup Plan")
        await store.upsertPlan(plan)

        let startedAt = Date(timeIntervalSince1970: 100)
        let endedAt = Date(timeIntervalSince1970: 120)
        let snapshot = PlanSnapshot(
            planId: plan.id,
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name,
            capturedAt: startedAt
        )
        let session = Session(
            id: UUID(),
            status: .completed,
            startedAt: startedAt,
            endedAt: endedAt,
            planSnapshot: snapshot,
            completedSets: 2,
            totalSets: 2,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            events: [.completed(occurredAt: endedAt)]
        )
        await store.upsertSession(session)

        let version = PlanVersion(
            planId: plan.id,
            status: .draft,
            versionNumber: 1,
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name
        )
        try await store.upsertPlanVersion(version)

        let recoverable = RecoverableSessionSnapshot(session: session, elapsedSeconds: 12, capturedAt: Date(timeIntervalSince1970: 110))
        await store.upsertRecoverableSessionSnapshot(recoverable)

        let exported = await store.exportBackupBundle(exportedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(exported.schemaVersion, PersistenceSchemaVersion.current)
        XCTAssertEqual(exported.plans.count, 1)
        XCTAssertEqual(exported.sessions.count, 1)
        XCTAssertEqual(exported.planVersions.count, 1)
        XCTAssertEqual(exported.recoverableSessionSnapshot?.elapsedSeconds, 12)

        await store.resetAllData()
        let emptyPlans = await store.fetchAllPlans()
        let emptySessions = await store.fetchAllSessions()
        let emptyVersions = await store.fetchAllPlanVersions()
        let emptyRecoverable = await store.fetchRecoverableSessionSnapshot()
        XCTAssertTrue(emptyPlans.isEmpty)
        XCTAssertTrue(emptySessions.isEmpty)
        XCTAssertTrue(emptyVersions.isEmpty)
        XCTAssertNil(emptyRecoverable)

        try await store.importBackupBundle(exported, overwrite: true)
        let importedPlans = await store.fetchAllPlans()
        let importedSessions = await store.fetchAllSessions()
        let importedVersions = await store.fetchAllPlanVersions()
        let importedRecoverable = await store.fetchRecoverableSessionSnapshot()
        XCTAssertEqual(importedPlans.map(\.id), [plan.id])
        XCTAssertEqual(importedSessions.map(\.id), [session.id])
        XCTAssertEqual(importedVersions.map(\.id), [version.id])
        XCTAssertEqual(importedRecoverable?.elapsedSeconds, 12)
    }

    func test_importBackupBundle_throwsWhenSchemaTooNew() async {
        let suite = "interfit.tests.backup.schema.\(UUID().uuidString)"
        let store = CoreDataPersistenceStore(userDefaultsSuiteName: suite)
        await store.resetAllData()

        let bundle = InterfitBackupBundle(
            schemaVersion: PersistenceSchemaVersion.current + 1,
            plans: [],
            sessions: [],
            planVersions: [],
            recoverableSessionSnapshot: nil
        )

        do {
            try await store.importBackupBundle(bundle, overwrite: true)
            XCTFail("Expected import to throw.")
        } catch let error as InterfitBackupImportError {
            XCTAssertEqual(error, .unsupportedSchemaVersion(found: PersistenceSchemaVersion.current + 1, maxSupported: PersistenceSchemaVersion.current))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
