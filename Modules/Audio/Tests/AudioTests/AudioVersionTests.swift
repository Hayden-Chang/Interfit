import XCTest
@testable import Audio

final class AudioVersionTests: XCTestCase {
    func test_audioVersion_isNonEmpty() {
        XCTAssertFalse(AudioVersion.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

