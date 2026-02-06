import XCTest
@testable import Shared

final class PlanSummaryConversionTests: XCTestCase {
    func test_fromSnapshot_copiesFields() {
        let capturedAt = Date(timeIntervalSince1970: 123)
        let planId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let selection = MusicSelection(
            source: .appleMusic,
            type: .track,
            externalId: "track.1",
            displayTitle: "Track 1",
            playMode: .continue
        )
        let strategy = MusicStrategy(global: selection, workCycle: [], restCycle: [])

        let snapshot = PlanSnapshot(
            planId: planId,
            setsCount: 6,
            workSeconds: 40,
            restSeconds: 20,
            name: "Snapshot Plan",
            musicStrategy: strategy,
            capturedAt: capturedAt
        )

        let plan = Plan.from(snapshot: snapshot)
        XCTAssertEqual(plan.id, planId)
        XCTAssertEqual(plan.setsCount, 6)
        XCTAssertEqual(plan.workSeconds, 40)
        XCTAssertEqual(plan.restSeconds, 20)
        XCTAssertEqual(plan.name, "Snapshot Plan")
        XCTAssertEqual(plan.musicStrategy, strategy)
        XCTAssertEqual(plan.createdAt, capturedAt)
        XCTAssertEqual(plan.updatedAt, capturedAt)
    }

    func test_fallbackFromSession_prefersEffectiveValues_andUsesSnapshotName() {
        let startedAt = Date(timeIntervalSince1970: 50)
        let snapshot = PlanSnapshot(
            planId: nil,
            setsCount: 4,
            workSeconds: 30,
            restSeconds: 10,
            name: "Name From Snapshot",
            musicStrategy: nil,
            capturedAt: startedAt
        )

        let overrides = SessionOverrides(setsCount: 7, workSeconds: 45, restSeconds: 15)
        let session = Session(
            status: .paused,
            startedAt: startedAt,
            endedAt: nil,
            planSnapshot: snapshot,
            overrides: overrides,
            completedSets: 2,
            totalSets: 4,
            workSeconds: 30,
            restSeconds: 10,
            events: []
        )

        let plan = Plan.fallbackFrom(session: session)
        XCTAssertEqual(plan.setsCount, 7)
        XCTAssertEqual(plan.workSeconds, 45)
        XCTAssertEqual(plan.restSeconds, 15)
        XCTAssertEqual(plan.name, "Name From Snapshot")
        XCTAssertEqual(plan.createdAt, startedAt)
        XCTAssertEqual(plan.updatedAt, startedAt)
    }

    func test_fallbackFromSession_usesDefaultNameWhenNoSnapshot() {
        let startedAt = Date(timeIntervalSince1970: 50)
        let session = Session(
            status: .paused,
            startedAt: startedAt,
            endedAt: nil,
            planSnapshot: nil,
            overrides: nil,
            completedSets: 0,
            totalSets: 3,
            workSeconds: 25,
            restSeconds: 5,
            events: []
        )

        let plan = Plan.fallbackFrom(session: session, defaultName: "Fallback Name")
        XCTAssertEqual(plan.name, "Fallback Name")
        XCTAssertEqual(plan.setsCount, 3)
        XCTAssertEqual(plan.workSeconds, 25)
        XCTAssertEqual(plan.restSeconds, 5)
    }
}

