import XCTest
@testable import Shared

final class MusicAvailabilityTests: XCTestCase {
    func test_isUsable_onlyWhenAuthorizedWithoutIssues() {
        XCTAssertTrue(MusicAvailability(authorization: .authorized).isUsable)
        XCTAssertFalse(MusicAvailability(authorization: .notDetermined).isUsable)
        XCTAssertFalse(MusicAvailability(authorization: .denied).isUsable)
        XCTAssertFalse(MusicAvailability(authorization: .restricted).isUsable)
        XCTAssertFalse(MusicAvailability(authorization: .authorized, issues: [.resourceUnavailable]).isUsable)
    }

    func test_cta_guidesExpectedUserAction() {
        XCTAssertEqual(MusicAvailability(authorization: .notDetermined).cta, .requestPermission)
        XCTAssertEqual(MusicAvailability(authorization: .denied).cta, .openSettings)
        XCTAssertEqual(MusicAvailability(authorization: .restricted).cta, .none)

        XCTAssertEqual(MusicAvailability(authorization: .authorized).cta, .none)
        XCTAssertEqual(MusicAvailability(authorization: .authorized, issues: [.subscriptionUnavailable]).cta, .pickDifferentMusic)
        XCTAssertEqual(MusicAvailability(authorization: .authorized, issues: [.resourceUnavailable]).cta, .pickDifferentMusic)
    }
}

