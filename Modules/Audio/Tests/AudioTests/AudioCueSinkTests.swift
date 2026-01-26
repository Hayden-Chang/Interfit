import XCTest
import Foundation
import Shared
@testable import Audio

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&_value)
    }

    var value: Value {
        withLock { $0 }
    }
}

final class AudioCueSinkTests: XCTestCase {
    func test_mapping_for_key_events() {
        let workStart = CueEventRecord.segmentStart(segmentId: "w#1", kind: .work, setIndex: 1)
        let restStart = CueEventRecord.segmentStart(segmentId: "r#1", kind: .rest, setIndex: 1)
        XCTAssertEqual(AudioCueSink.map(workStart), [.beepTransition])
        XCTAssertEqual(AudioCueSink.map(restStart), [.beepShort])
        XCTAssertEqual(AudioCueSink.map(.workToRest(from: "w#1", to: "r#1")), [.beepWarning])
        XCTAssertEqual(AudioCueSink.map(.restToWork(from: "r#1", to: "w#2")), [.beepSuccess])
        XCTAssertEqual(AudioCueSink.map(.last3s(segmentId: "w#1")), [.beepShort])
        XCTAssertEqual(AudioCueSink.map(.paused()), [.beepWarning])
        XCTAssertEqual(AudioCueSink.map(.resumed()), [.beepShort])
        XCTAssertEqual(AudioCueSink.map(.completed()), [.beepSuccess])
    }

    func test_emit_respects_enabled_flag_and_calls_handler() {
        let captured = Locked<[[AudioCuePattern]]>([])
        let sinkOn = AudioCueSink(enabled: true) { patterns in captured.withLock { $0.append(patterns) } }
        let sinkOff = AudioCueSink(enabled: false) { patterns in captured.withLock { $0.append(patterns) } }

        sinkOn.emit(CueEventRecord.last3s(segmentId: "w#1"))
        sinkOff.emit(CueEventRecord.completed())

        XCTAssertEqual(captured.value.count, 1)
        XCTAssertEqual(captured.value.first, [.beepShort])
    }
}
