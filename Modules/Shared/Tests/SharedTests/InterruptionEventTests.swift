import XCTest
@testable import Shared

final class InterruptionEventTests: XCTestCase {
    func test_audioSessionBegan_mapsToInterruptionPause_andInterruptionDegrade() {
        let e = InterruptionEvent(kind: .audioSessionInterruptionBegan)
        XCTAssertEqual(e.recommendedPauseReason, .interruption)
        XCTAssertEqual(e.recommendedDegradeReason, .fallbackDueToInterruption)
    }

    func test_routeChange_mapsToSafetyPause_andRouteDegrade() {
        let e = InterruptionEvent(kind: .routeChanged, attributes: ["reason": "oldDeviceUnavailable"])
        XCTAssertEqual(e.recommendedPauseReason, .safety)
        XCTAssertEqual(e.recommendedDegradeReason, .fallbackDueToRouteChange)
        XCTAssertEqual(e.asSessionEventRecord().attributes["reason"], "oldDeviceUnavailable")
        XCTAssertEqual(e.asSessionEventRecord().attributes["kind"], "routeChanged")
    }
}

