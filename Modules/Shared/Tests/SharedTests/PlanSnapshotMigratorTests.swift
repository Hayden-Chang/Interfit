import XCTest
@testable import Shared

final class PlanSnapshotMigratorTests: XCTestCase {
    func test_decodeWithoutConfigVersion_defaultsAndMigratesToCurrent() throws {
        let json = """
        {
          "planId": "00000000-0000-0000-0000-000000000001",
          "setsCount": 3,
          "workSeconds": 30,
          "restSeconds": 10,
          "name": "HIIT",
          "capturedAt": 0
        }
        """
        let snapshot = try JSONDecoder().decode(PlanSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot.configVersion, PlanSnapshot.currentConfigVersion)
        XCTAssertEqual(snapshot.setsCount, 3)
        XCTAssertEqual(snapshot.workSeconds, 30)
        XCTAssertEqual(snapshot.restSeconds, 10)
        XCTAssertEqual(snapshot.name, "HIIT")
    }

    func test_migrate_isIdempotentAtCurrentVersion() {
        let snapshot = PlanSnapshot(
            planId: UUID(),
            planVersionId: UUID(),
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "Test",
            capturedAt: Date(timeIntervalSince1970: 1),
            configVersion: PlanSnapshot.currentConfigVersion
        )
        let outcome = PlanSnapshotMigrator.migrate(snapshot)
        XCTAssertEqual(outcome.snapshot, snapshot)
        XCTAssertFalse(outcome.didMigrate)
        XCTAssertNil(outcome.error)
    }

    func test_migrate_futureVersion_isExplainableAndNonThrowing() {
        let snapshot = PlanSnapshot(
            planId: UUID(),
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "Future",
            configVersion: PlanSnapshot.currentConfigVersion + 1
        )
        let outcome = PlanSnapshotMigrator.migrate(snapshot)
        XCTAssertEqual(outcome.snapshot, snapshot)
        XCTAssertFalse(outcome.didMigrate)
        XCTAssertEqual(outcome.error, .unsupportedFutureVersion(found: snapshot.configVersion, supportedCurrent: PlanSnapshot.currentConfigVersion))
    }
}

