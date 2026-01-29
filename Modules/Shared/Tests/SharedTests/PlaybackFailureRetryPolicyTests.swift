import XCTest
@testable import Shared

final class PlaybackFailureRetryPolicyTests: XCTestCase {
    func test_offline_fastRetries_twice_thenFallsBack() {
        XCTAssertEqual(
            PlaybackFailureRetryPolicy.decide(
                context: .init(attempt: 0, kind: .offline, hasCurrentPlayback: false, cuesEnabled: true)
            ),
            .retry(afterSeconds: 0.15)
        )
        XCTAssertEqual(
            PlaybackFailureRetryPolicy.decide(
                context: .init(attempt: 1, kind: .offline, hasCurrentPlayback: false, cuesEnabled: true)
            ),
            .retry(afterSeconds: 0.35)
        )

        let decision = PlaybackFailureRetryPolicy.decide(
            context: .init(attempt: 2, kind: .offline, hasCurrentPlayback: false, cuesEnabled: true)
        )
        XCTAssertEqual(decision, .fallback(.init(action: .cuesOnly, degradeReason: .fallbackDueToOffline)))
    }

    func test_permission_noRetry_fallsBackImmediately() {
        let decision = PlaybackFailureRetryPolicy.decide(
            context: .init(attempt: 0, kind: .permission, hasCurrentPlayback: true, cuesEnabled: true)
        )
        XCTAssertEqual(decision, .fallback(.init(action: .continueCurrent, degradeReason: .fallbackDueToPermission)))
    }

    func test_unknown_fastRetries_thenFallsBackWithUnknownReason() {
        let decision = PlaybackFailureRetryPolicy.decide(
            context: .init(attempt: 2, kind: .unknown, hasCurrentPlayback: false, cuesEnabled: false)
        )
        XCTAssertEqual(decision, .fallback(.init(action: .silence, degradeReason: .unknown)))
    }
}

