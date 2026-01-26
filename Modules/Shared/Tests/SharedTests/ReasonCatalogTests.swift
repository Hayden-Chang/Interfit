import XCTest
@testable import Shared

final class ReasonCatalogTests: XCTestCase {
    func test_errorReason_titlesAndMessages_areNonEmpty() {
        for reason in ErrorReason.allCases {
            XCTAssertFalse(reason.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(reason.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func test_degradeReason_titlesAndMessages_areNonEmpty() {
        for reason in DegradeReason.allCases {
            XCTAssertFalse(reason.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(reason.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

