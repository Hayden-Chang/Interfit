import XCTest
@testable import Shared

final class SiriInterruptionPolicyTests: XCTestCase {
    func test_threshold_isConfigurable() {
        let policy = SiriInterruptionPolicy(pauseThresholdSeconds: 5)
        XCTAssertEqual(policy.decide(durationSeconds: 4.9), .ignore)
        XCTAssertEqual(policy.decide(durationSeconds: 5.1), .pause)
    }

    func test_defaultThreshold_isThreeSeconds() {
        let policy = SiriInterruptionPolicy()
        XCTAssertEqual(policy.decide(durationSeconds: 3.0), .ignore)
        XCTAssertEqual(policy.decide(durationSeconds: 3.001), .pause)
    }
}

