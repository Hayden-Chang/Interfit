import XCTest
@testable import Shared

final class PlaybackSelectionSwitchTests: XCTestCase {
    func test_sameSelection_doesNotSwitch() {
        let current = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "A", playMode: .continue)
        let next = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "B", playMode: .continue)
        XCTAssertEqual(PlaybackSelectionSwitch.decide(current: current, next: next), .noChange)
    }

    func test_differentSelection_switches() {
        let current = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "A", playMode: .continue)
        let next = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.2", displayTitle: "B", playMode: .continue)
        XCTAssertEqual(PlaybackSelectionSwitch.decide(current: current, next: next), .switchSelection(next))
    }
}

