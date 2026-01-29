import XCTest
@testable import Shared

final class WorkoutSessionEnginePlanSnapshotTests: XCTestCase {
    func test_engine_captures_planSnapshot_at_start() throws {
        let plan = Plan(setsCount: 3, workSeconds: 20, restSeconds: 10, name: "SnapshotPlan")
        let now = Date(timeIntervalSince1970: 123)

        let engine = try WorkoutSessionEngine(plan: plan, now: now)

        let snapshot = try XCTUnwrap(engine.session.planSnapshot)
        XCTAssertEqual(snapshot.planId, plan.id)
        XCTAssertEqual(snapshot.planVersionId, nil)
        XCTAssertEqual(snapshot.setsCount, plan.setsCount)
        XCTAssertEqual(snapshot.workSeconds, plan.workSeconds)
        XCTAssertEqual(snapshot.restSeconds, plan.restSeconds)
        XCTAssertEqual(snapshot.name, plan.name)
        XCTAssertEqual(snapshot.capturedAt, now)
    }
}

