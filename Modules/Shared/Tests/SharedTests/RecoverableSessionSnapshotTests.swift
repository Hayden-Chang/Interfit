import XCTest
@testable import Shared

final class RecoverableSessionSnapshotTests: XCTestCase {
    func test_codable_roundTrip() throws {
        let t0 = Date(timeIntervalSince1970: 0)
        let session = Session(
            status: .paused,
            startedAt: t0,
            endedAt: nil,
            planSnapshot: PlanSnapshot(planId: nil, setsCount: 2, workSeconds: 10, restSeconds: 5, name: "Test", capturedAt: t0),
            completedSets: 1,
            totalSets: 2,
            workSeconds: 10,
            restSeconds: 5,
            events: [.paused(occurredAt: t0, reason: PauseReason.safety.rawValue)]
        )
        let snapshot = RecoverableSessionSnapshot(session: session, elapsedSeconds: 12, capturedAt: Date(timeIntervalSince1970: 12))

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RecoverableSessionSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }
}

