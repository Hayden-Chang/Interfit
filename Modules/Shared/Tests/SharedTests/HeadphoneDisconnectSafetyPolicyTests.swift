import XCTest
@testable import Shared

final class HeadphoneDisconnectSafetyPolicyTests: XCTestCase {
    func test_oldDeviceUnavailable_requiresSafetyPause() {
        let policy = HeadphoneDisconnectSafetyPolicy()
        let event = InterruptionEvent(kind: .routeChanged, attributes: ["reason": "oldDeviceUnavailable"])
        XCTAssertEqual(policy.decide(for: event), .requireSafetyPause)
    }

    func test_otherRouteChange_noAction() {
        let policy = HeadphoneDisconnectSafetyPolicy()
        let event = InterruptionEvent(kind: .routeChanged, attributes: ["reason": "newDeviceAvailable"])
        XCTAssertEqual(policy.decide(for: event), .noAction)
    }
}

