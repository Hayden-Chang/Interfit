import XCTest
@testable import Shared

final class HapticsCueSinkTests: XCTestCase {
    func test_mapping_for_segmentStart_work_and_rest() {
        let workEvent = CueEventRecord.segmentStart(segmentId: "work#1", kind: .work, setIndex: 1)
        let restEvent = CueEventRecord.segmentStart(segmentId: "rest#1", kind: .rest, setIndex: 1)
        XCTAssertEqual(HapticsCueSink.map(workEvent), [.impactRigid])
        XCTAssertEqual(HapticsCueSink.map(restEvent), [.impactSoft])
    }

    func test_mapping_for_transitions_and_completed() {
        let w2r = CueEventRecord.workToRest(from: "w#1", to: "r#1")
        let r2w = CueEventRecord.restToWork(from: "r#1", to: "w#2")
        let last3s = CueEventRecord.last3s(segmentId: "w#1")
        let paused = CueEventRecord.paused()
        let resumed = CueEventRecord.resumed()
        let completed = CueEventRecord.completed()
        XCTAssertEqual(HapticsCueSink.map(w2r), [.notificationWarning])
        XCTAssertEqual(HapticsCueSink.map(r2w), [.notificationSuccess])
        XCTAssertEqual(HapticsCueSink.map(last3s), [.impactLight])
        XCTAssertEqual(HapticsCueSink.map(paused), [.notificationWarning])
        XCTAssertEqual(HapticsCueSink.map(resumed), [.impactLight])
        XCTAssertEqual(HapticsCueSink.map(completed), [.notificationSuccess])
    }

    func test_emit_respects_enabled_flag_and_calls_handler() {
        let captured = Locked<[[HapticPattern]]>([])
        let sinkOn = HapticsCueSink(enabled: true) { patterns in
            captured.withLock { $0.append(patterns) }
        }
        let sinkOff = HapticsCueSink(enabled: false) { patterns in
            captured.withLock { $0.append(patterns) }
        }

        sinkOn.emit(.last3s(segmentId: "w#1"))
        sinkOff.emit(.completed())

        XCTAssertEqual(captured.value.count, 1)
        XCTAssertEqual(captured.value.first, [.impactLight])
    }
}
