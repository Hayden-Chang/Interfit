import XCTest
@testable import Shared

final class BackgroundCueNotificationRefreshPolicyTests: XCTestCase {
    func test_decide_withoutSessionStatus_isNoOp() {
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: nil, appIsActive: true),
            .noOp
        )
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: nil, appIsActive: false),
            .noOp
        )
    }

    func test_decide_runningInBackground_schedulesNotifications() {
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: .running, appIsActive: false),
            .schedule
        )
    }

    func test_decide_existingSessionOutsideBackground_cancelsNotifications() {
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: .running, appIsActive: true),
            .cancel
        )
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: .idle, appIsActive: false),
            .cancel
        )
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: .paused, appIsActive: false),
            .cancel
        )
        XCTAssertEqual(
            BackgroundCueNotificationRefreshPolicy.decide(sessionStatus: .completed, appIsActive: true),
            .cancel
        )
    }
}
