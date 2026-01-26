import XCTest
@testable import Shared

final class WorkoutStructureTests: XCTestCase {
    func test_totalSeconds_formula_matchesPlanRule() {
        let structure = WorkoutStructure(setsCount: 3, workSeconds: 10, restSeconds: 5)
        XCTAssertEqual(structure.totalSeconds, (3 * 10) + (2 * 5))
        XCTAssertEqual(structure.segmentCount, 5)
    }

    func test_restZero_hasOnlyWorkSegments() {
        let structure = WorkoutStructure(setsCount: 4, workSeconds: 30, restSeconds: 0)
        XCTAssertEqual(structure.totalSeconds, 120)
        XCTAssertEqual(structure.segmentCount, 4)

        XCTAssertEqual(structure.progress(atElapsedSeconds: 0).currentSegment?.kind, .work)
        XCTAssertEqual(structure.progress(atElapsedSeconds: 0).currentSegment?.setIndex, 1)
        XCTAssertEqual(structure.progress(atElapsedSeconds: 0).currentSegmentRemainingSeconds, 30)
        XCTAssertEqual(structure.progress(atElapsedSeconds: 0).completedSets, 0)

        // Exactly at boundary: should advance to set 2.
        let p10 = structure.progress(atElapsedSeconds: 30)
        XCTAssertEqual(p10.currentSegment?.kind, .work)
        XCTAssertEqual(p10.currentSegment?.setIndex, 2)
        XCTAssertEqual(p10.completedSets, 1)
        XCTAssertEqual(p10.currentSegmentRemainingSeconds, 30)

        // Near the end.
        let p119 = structure.progress(atElapsedSeconds: 119)
        XCTAssertEqual(p119.currentSegment?.setIndex, 4)
        XCTAssertEqual(p119.currentSegmentRemainingSeconds, 1)
        XCTAssertEqual(p119.completedSets, 3)

        // End: completed.
        let p120 = structure.progress(atElapsedSeconds: 120)
        XCTAssertTrue(p120.isCompleted)
        XCTAssertEqual(p120.completedSets, 4)
        XCTAssertNil(p120.currentSegment)
        XCTAssertEqual(p120.currentSegmentRemainingSeconds, 0)
    }

    func test_workRestAlternates_andNoRestAfterLastSet() {
        let structure = WorkoutStructure(setsCount: 3, workSeconds: 10, restSeconds: 5)

        // 0..9: work 1
        let p0 = structure.progress(atElapsedSeconds: 0)
        XCTAssertEqual(p0.currentSegment?.kind, .work)
        XCTAssertEqual(p0.currentSegment?.setIndex, 1)
        XCTAssertEqual(p0.currentSegmentRemainingSeconds, 10)
        XCTAssertEqual(p0.completedSets, 0)

        // 10..14: rest after set 1
        let p10 = structure.progress(atElapsedSeconds: 10)
        XCTAssertEqual(p10.currentSegment?.kind, .rest)
        XCTAssertEqual(p10.currentSegment?.setIndex, 1)
        XCTAssertEqual(p10.currentSegmentRemainingSeconds, 5)
        XCTAssertEqual(p10.completedSets, 1)

        let p12 = structure.progress(atElapsedSeconds: 12)
        XCTAssertEqual(p12.currentSegment?.kind, .rest)
        XCTAssertEqual(p12.currentSegmentElapsedSeconds, 2)
        XCTAssertEqual(p12.currentSegmentRemainingSeconds, 3)

        // 15..24: work 2
        let p15 = structure.progress(atElapsedSeconds: 15)
        XCTAssertEqual(p15.currentSegment?.kind, .work)
        XCTAssertEqual(p15.currentSegment?.setIndex, 2)
        XCTAssertEqual(p15.completedSets, 1)
        XCTAssertEqual(p15.currentSegmentRemainingSeconds, 10)

        // 25..29: rest after set 2
        let p25 = structure.progress(atElapsedSeconds: 25)
        XCTAssertEqual(p25.currentSegment?.kind, .rest)
        XCTAssertEqual(p25.currentSegment?.setIndex, 2)
        XCTAssertEqual(p25.completedSets, 2)

        // 30..39: work 3 (no rest after last set)
        let p30 = structure.progress(atElapsedSeconds: 30)
        XCTAssertEqual(p30.currentSegment?.kind, .work)
        XCTAssertEqual(p30.currentSegment?.setIndex, 3)
        XCTAssertEqual(p30.completedSets, 2)

        let p39 = structure.progress(atElapsedSeconds: 39)
        XCTAssertEqual(p39.currentSegment?.kind, .work)
        XCTAssertEqual(p39.currentSegmentRemainingSeconds, 1)

        let p40 = structure.progress(atElapsedSeconds: 40)
        XCTAssertTrue(p40.isCompleted)
        XCTAssertEqual(p40.completedSets, 3)
        XCTAssertNil(p40.currentSegment)
    }
}

