import XCTest
@testable import Shared

final class MusicStrategyFactoryTests: XCTestCase {
    func test_simple_nilNil_returnsNil() {
        XCTAssertNil(MusicStrategyFactory.simple(work: nil, rest: nil))
    }

    func test_simple_buildsSingleElementCycles() {
        let work = MusicSelection(source: .appleMusic, type: .track, externalId: "w", displayTitle: "Work", playMode: .continue)
        let rest = MusicSelection(source: .appleMusic, type: .track, externalId: "r", displayTitle: "Rest", playMode: .continue)
        let strategy = MusicStrategyFactory.simple(work: work, rest: rest)
        XCTAssertEqual(strategy?.workCycle, [work])
        XCTAssertEqual(strategy?.restCycle, [rest])
    }

    func test_perSet_buildsWorkCycleAndSingleRest() {
        let w1 = MusicSelection(source: .appleMusic, type: .track, externalId: "w1", displayTitle: "W1", playMode: .continue)
        let w2 = MusicSelection(source: .appleMusic, type: .track, externalId: "w2", displayTitle: "W2", playMode: .continue)
        let rest = MusicSelection(source: .appleMusic, type: .track, externalId: "r", displayTitle: "Rest", playMode: .continue)
        let strategy = MusicStrategyFactory.perSet(workCycle: [w1, w2], rest: rest)
        XCTAssertEqual(strategy?.workCycle, [w1, w2])
        XCTAssertEqual(strategy?.restCycle, [rest])
    }
}

