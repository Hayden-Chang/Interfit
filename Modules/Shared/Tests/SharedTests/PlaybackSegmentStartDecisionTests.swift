import XCTest
@testable import Shared

final class PlaybackSegmentStartDecisionTests: XCTestCase {
    func test_nextNil_noChange() {
        XCTAssertEqual(PlaybackSegmentStartDecision.decide(current: nil, next: nil), .noChange)
    }

    func test_selectionChanges_switchSelection_withDirective() {
        let current = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "A", playMode: .continue)
        let next = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.2", displayTitle: "B", playMode: .shuffleOnSegment)
        XCTAssertEqual(
            PlaybackSegmentStartDecision.decide(current: current, next: next),
            .switchSelection(next, directive: .shuffleSelection)
        )
    }

    func test_sameSelection_continue_noChange() {
        let current = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "A", playMode: .continue)
        let next = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "B", playMode: .continue)
        XCTAssertEqual(PlaybackSegmentStartDecision.decide(current: current, next: next), .noChange)
    }

    func test_sameSelection_restart_appliesDirective() {
        let current = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "A", playMode: .restartOnSegment)
        let next = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "B", playMode: .restartOnSegment)
        XCTAssertEqual(PlaybackSegmentStartDecision.decide(current: current, next: next), .applyDirective(.restartSelection))
    }

    func test_sameSelection_shuffle_appliesDirective() {
        let current = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "A", playMode: .shuffleOnSegment)
        let next = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.1", displayTitle: "B", playMode: .shuffleOnSegment)
        XCTAssertEqual(PlaybackSegmentStartDecision.decide(current: current, next: next), .applyDirective(.shuffleSelection))
    }
}
