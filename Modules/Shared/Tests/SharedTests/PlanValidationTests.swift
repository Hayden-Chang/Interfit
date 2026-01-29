import XCTest
@testable import Shared

final class PlanValidationTests: XCTestCase {
    func test_validateRecommended_validPlan_hasNoIssues() {
        let plan = Plan(setsCount: 10, workSeconds: 90, restSeconds: 30, name: "OK")
        XCTAssertEqual(plan.validate(), [])
    }

    func test_validateRecommended_setsCountOutOfRange() {
        let plan = Plan(setsCount: 0, workSeconds: 90, restSeconds: 30, name: "Bad sets")
        XCTAssertEqual(plan.validate(), [.setsCountOutOfRange(min: 1, max: 99, actual: 0)])
    }

    func test_validateRecommended_workSecondsOutOfRange() {
        let plan = Plan(setsCount: 10, workSeconds: 9, restSeconds: 30, name: "Bad work")
        XCTAssertEqual(plan.validate(), [.workSecondsOutOfRange(min: 10, max: 1800, actual: 9)])
    }

    func test_validateRecommended_restSecondsOutOfRange() {
        let plan = Plan(setsCount: 10, workSeconds: 90, restSeconds: -1, name: "Bad rest")
        XCTAssertEqual(plan.validate(), [.restSecondsOutOfRange(min: 0, max: 1800, actual: -1)])
    }
}

