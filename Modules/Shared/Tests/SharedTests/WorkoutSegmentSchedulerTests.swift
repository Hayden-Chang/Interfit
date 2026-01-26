import XCTest
@testable import Shared

final class WorkoutSegmentSchedulerTests: XCTestCase {
    func test_emitsOncePerSegment_andDoesNotDuplicate() {
        let structure = WorkoutStructure(setsCount: 3, workSeconds: 10, restSeconds: 5)
        var scheduler = WorkoutSegmentScheduler(structure: structure)

        // First update enters first segment (work 1)
        let c0 = scheduler.update(elapsedSeconds: 0)
        XCTAssertEqual(c0?.from, nil)
        XCTAssertEqual(c0?.to.kind, .work)
        XCTAssertEqual(c0?.to.setIndex, 1)

        // Same time / still in same segment → no duplicate.
        XCTAssertNil(scheduler.update(elapsedSeconds: 0))
        XCTAssertNil(scheduler.update(elapsedSeconds: 9))

        // Boundary: work1 -> rest1
        let c10 = scheduler.update(elapsedSeconds: 10)
        XCTAssertEqual(c10?.from?.kind, .work)
        XCTAssertEqual(c10?.from?.setIndex, 1)
        XCTAssertEqual(c10?.to.kind, .rest)
        XCTAssertEqual(c10?.to.setIndex, 1)

        // Still rest1
        XCTAssertNil(scheduler.update(elapsedSeconds: 12))

        // rest1 -> work2
        let c15 = scheduler.update(elapsedSeconds: 15)
        XCTAssertEqual(c15?.to.kind, .work)
        XCTAssertEqual(c15?.to.setIndex, 2)

        // work2 -> rest2
        let c25 = scheduler.update(elapsedSeconds: 25)
        XCTAssertEqual(c25?.to.kind, .rest)
        XCTAssertEqual(c25?.to.setIndex, 2)

        // rest2 -> work3
        let c30 = scheduler.update(elapsedSeconds: 30)
        XCTAssertEqual(c30?.to.kind, .work)
        XCTAssertEqual(c30?.to.setIndex, 3)

        // Completion: should reset current to nil and not emit segmentChanged repeatedly.
        XCTAssertNil(scheduler.update(elapsedSeconds: 40))
        XCTAssertNil(scheduler.current)
        XCTAssertNil(scheduler.update(elapsedSeconds: 41))
    }

    func test_largeJump_emitsSingleLatestSegmentChange() {
        let structure = WorkoutStructure(setsCount: 4, workSeconds: 30, restSeconds: 10)
        var scheduler = WorkoutSegmentScheduler(structure: structure)

        XCTAssertEqual(scheduler.update(elapsedSeconds: 0)?.to.stableId, "work#1")

        // Simulate background jump forward: should emit a single change to the current segment (not multiple).
        // Total timeline: w1(30) r1(10) w2(30) r2(10) w3(30) r3(10) w4(30)
        // elapsed 85 lands in w3 (30+10+30+10+5)
        let change = scheduler.update(elapsedSeconds: 85)
        XCTAssertEqual(change?.to.stableId, "work#3")

        // Subsequent updates in same segment: no duplicates.
        XCTAssertNil(scheduler.update(elapsedSeconds: 90))
    }
}

