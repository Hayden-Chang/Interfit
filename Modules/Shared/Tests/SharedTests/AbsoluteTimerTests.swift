import XCTest
@testable import Shared

final class AbsoluteTimerTests: XCTestCase {
    func test_timer_countsDown_withoutDrift() {
        var timer = AbsoluteTimer(totalSeconds: 30)
        let t0 = Date(timeIntervalSince1970: 0)
        timer.start(at: t0)

        XCTAssertEqual(timer.remainingSeconds(at: Date(timeIntervalSince1970: 10)), 20)
        XCTAssertEqual(timer.elapsedSeconds(at: Date(timeIntervalSince1970: 10)), 10)
    }

    func test_pause_resume_doesNotConsumeTime() {
        var timer = AbsoluteTimer(totalSeconds: 30)
        let t0 = Date(timeIntervalSince1970: 0)
        timer.start(at: t0)

        let t10 = Date(timeIntervalSince1970: 10)
        timer.pause(at: t10)

        // paused for 10s, remaining should not change during pause
        let t20 = Date(timeIntervalSince1970: 20)
        XCTAssertEqual(timer.remainingSeconds(at: t20), 20)

        timer.resume(at: t20)

        // 5s after resume => total active elapsed = 10 + 5
        let t25 = Date(timeIntervalSince1970: 25)
        XCTAssertEqual(timer.elapsedSeconds(at: t25), 15)
        XCTAssertEqual(timer.remainingSeconds(at: t25), 15)
    }
}

