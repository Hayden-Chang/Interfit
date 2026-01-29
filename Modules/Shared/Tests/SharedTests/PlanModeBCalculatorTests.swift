import XCTest
@testable import Shared

final class PlanModeBCalculatorTests: XCTestCase {
    func test_compute_returnsNilForInvalidInputs() {
        XCTAssertNil(PlanModeBCalculator.compute(.init(totalSeconds: 0, setsCount: 1, workPart: 1, restPart: 1)))
        XCTAssertNil(PlanModeBCalculator.compute(.init(totalSeconds: 10, setsCount: 0, workPart: 1, restPart: 1)))
        XCTAssertNil(PlanModeBCalculator.compute(.init(totalSeconds: 10, setsCount: 1, workPart: 0, restPart: 1)))
        XCTAssertNil(PlanModeBCalculator.compute(.init(totalSeconds: 10, setsCount: 1, workPart: 1, restPart: -1)))
    }

    func test_compute_whenRestPartZero_setsRestZero() {
        let out = PlanModeBCalculator.compute(.init(totalSeconds: 60, setsCount: 3, workPart: 1, restPart: 0))
        XCTAssertEqual(out?.workSeconds, 20)
        XCTAssertEqual(out?.restSeconds, 0)
        XCTAssertEqual(out?.effectiveTotalSeconds, 60)
    }

    func test_compute_returnsEffectiveTotalLessOrEqualTarget() {
        let input = PlanModeBInput(totalSeconds: 95, setsCount: 4, workPart: 2, restPart: 1)
        let out = PlanModeBCalculator.compute(input)
        XCTAssertNotNil(out)
        if let out {
            XCTAssertGreaterThanOrEqual(out.workSeconds, 0)
            XCTAssertGreaterThanOrEqual(out.restSeconds, 0)
            XCTAssertLessThanOrEqual(out.effectiveTotalSeconds, input.totalSeconds)
        }
    }
}

