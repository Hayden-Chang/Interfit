import XCTest
@testable import Shared

final class MusicPlayModeTests: XCTestCase {
    func test_directiveOnSegmentStart_mapping() {
        XCTAssertEqual(MusicPlayMode.continue.directiveOnSegmentStart, .none)
        XCTAssertEqual(MusicPlayMode.restartOnSegment.directiveOnSegmentStart, .restartSelection)
        XCTAssertEqual(MusicPlayMode.shuffleOnSegment.directiveOnSegmentStart, .shuffleSelection)
    }
}

