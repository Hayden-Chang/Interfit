import XCTest
@testable import Shared

final class MusicStrategyTests: XCTestCase {
    func test_cycleSelection_isReproducible_1BasedSetIndex() {
        let a = MusicSelection(source: .appleMusic, type: .playlist, externalId: "a", displayTitle: "A", playMode: .continue)
        let b = MusicSelection(source: .appleMusic, type: .playlist, externalId: "b", displayTitle: "B", playMode: .continue)
        let strategy = MusicStrategy(workCycle: [a, b])

        XCTAssertEqual(strategy.selection(for: .work, setIndex: 1), a)
        XCTAssertEqual(strategy.selection(for: .work, setIndex: 2), b)
        XCTAssertEqual(strategy.selection(for: .work, setIndex: 3), a)
        XCTAssertEqual(strategy.selection(for: .work, setIndex: 4), b)
    }

    func test_cycle_isPerSegmentKind() {
        let w = MusicSelection(source: .localLibrary, type: .playlist, externalId: "w", displayTitle: "W", playMode: .continue)
        let r = MusicSelection(source: .localLibrary, type: .playlist, externalId: "r", displayTitle: "R", playMode: .continue)
        let strategy = MusicStrategy(workCycle: [w], restCycle: [r])

        XCTAssertEqual(strategy.selection(for: .work, setIndex: 1), w)
        XCTAssertEqual(strategy.selection(for: .rest, setIndex: 1), r)
    }

    func test_fallsBackToGlobalWhenCycleEmpty() {
        let global = MusicSelection(source: .appleMusic, type: .playlist, externalId: "g", displayTitle: "G", playMode: .continue)
        let strategy = MusicStrategy(global: global, workCycle: [], restCycle: [])

        XCTAssertEqual(strategy.selection(for: .work, setIndex: 1), global)
        XCTAssertEqual(strategy.selection(for: .rest, setIndex: 99), global)
    }
}

