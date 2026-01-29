import XCTest
@testable import Shared

final class SessionOverridesEffectiveValuesTests: XCTestCase {
    func test_effectiveValues_fallBackToSessionFields_whenNoSnapshotOrOverrides() {
        let session = Session(
            status: .running,
            startedAt: Date(timeIntervalSince1970: 0),
            planSnapshot: nil,
            overrides: nil,
            completedSets: 0,
            totalSets: 5,
            workSeconds: 30,
            restSeconds: 10,
            events: []
        )

        XCTAssertEqual(session.effectiveSetsCount, 5)
        XCTAssertEqual(session.effectiveWorkSeconds, 30)
        XCTAssertEqual(session.effectiveRestSeconds, 10)
        XCTAssertFalse(session.hasOverrides)
    }

    func test_effectiveValues_useSnapshot_whenPresent_andNoOverrides() {
        let snapshot = PlanSnapshot(planId: UUID(), setsCount: 8, workSeconds: 40, restSeconds: 20, name: "Snap")
        let session = Session(
            status: .running,
            startedAt: Date(timeIntervalSince1970: 0),
            planSnapshot: snapshot,
            overrides: nil,
            completedSets: 0,
            totalSets: 5,
            workSeconds: 30,
            restSeconds: 10,
            events: []
        )

        XCTAssertEqual(session.effectiveSetsCount, 8)
        XCTAssertEqual(session.effectiveWorkSeconds, 40)
        XCTAssertEqual(session.effectiveRestSeconds, 20)
        XCTAssertFalse(session.hasOverrides)
    }

    func test_effectiveValues_preferOverrides_overSnapshot() {
        let snapshot = PlanSnapshot(planId: UUID(), setsCount: 8, workSeconds: 40, restSeconds: 20, name: "Snap")
        let overrides = SessionOverrides(setsCount: 9, workSeconds: 45, restSeconds: nil)
        let session = Session(
            status: .running,
            startedAt: Date(timeIntervalSince1970: 0),
            planSnapshot: snapshot,
            overrides: overrides,
            completedSets: 0,
            totalSets: 5,
            workSeconds: 30,
            restSeconds: 10,
            events: []
        )

        XCTAssertEqual(session.effectiveSetsCount, 9)
        XCTAssertEqual(session.effectiveWorkSeconds, 45)
        XCTAssertEqual(session.effectiveRestSeconds, 20)
        XCTAssertTrue(session.hasOverrides)
    }
}

