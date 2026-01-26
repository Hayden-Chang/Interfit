import XCTest
@testable import Shared

final class SharedVersionTests: XCTestCase {
    func test_sharedVersion_isNonEmpty() {
        XCTAssertFalse(SharedVersion.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

