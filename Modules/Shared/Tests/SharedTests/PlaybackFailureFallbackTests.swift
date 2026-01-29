import XCTest
@testable import Shared

final class PlaybackFailureFallbackTests: XCTestCase {
    func test_prefersContinueCurrent_whenAvailable() {
        let outcome = PlaybackFailureFallback.decide(context: .init(hasCurrentPlayback: true, cuesEnabled: true))
        XCTAssertEqual(outcome.action, .continueCurrent)
    }

    func test_fallsBackToCuesOnly_whenNoCurrentPlayback() {
        let outcome = PlaybackFailureFallback.decide(context: .init(hasCurrentPlayback: false, cuesEnabled: true))
        XCTAssertEqual(outcome.action, .cuesOnly)
    }

    func test_lastResort_silence_whenNoCurrentPlayback_andCuesDisabled() {
        let outcome = PlaybackFailureFallback.decide(context: .init(hasCurrentPlayback: false, cuesEnabled: false))
        XCTAssertEqual(outcome.action, .silence)
    }
}

