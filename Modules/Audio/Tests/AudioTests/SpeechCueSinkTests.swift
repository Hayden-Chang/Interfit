import XCTest
import Shared
@testable import Audio

final class SpeechCueSinkTests: XCTestCase {
    func test_segment_start_rest_is_suppressed_in_background() {
        let event = CueEventRecord.segmentStart(segmentId: "r#1", kind: .rest, setIndex: 1)
        XCTAssertEqual(SpeechCueSink.resolveAction(for: event, isForeground: false), .none)
    }

    func test_segment_start_rest_uses_rest_voice_in_foreground() {
        let event = CueEventRecord.segmentStart(segmentId: "r#1", kind: .rest, setIndex: 1)
        XCTAssertEqual(
            SpeechCueSink.resolveAction(for: event, isForeground: true),
            .playMP3(name: "time_to_rest", subdirectory: "rest_mp3")
        )
    }

    func test_segment_start_work_uses_numbered_voice() {
        let event = CueEventRecord.segmentStart(segmentId: "w#3", kind: .work, setIndex: 3)
        XCTAssertEqual(
            SpeechCueSink.resolveAction(for: event, isForeground: true),
            .playMP3(name: "set_3_start", subdirectory: "work_mp3")
        )
    }
}
