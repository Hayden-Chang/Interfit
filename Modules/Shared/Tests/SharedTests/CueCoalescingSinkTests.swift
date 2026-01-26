import XCTest
@testable import Shared

final class CueCoalescingSinkTests: XCTestCase {
    private final class Collecting: CueSink {
        var events: [CueEventRecord] = []
        func emit(_ event: CueEventRecord) { events.append(event) }
    }

    func test_drops_multiple_cues_in_same_second() {
        let collector = Collecting()
        let sink = CueCoalescingSink(collector)
        let base = Date(timeIntervalSince1970: 100)
        sink.emit(.segmentStart(occurredAt: base, segmentId: "w#1", kind: .work, setIndex: 1))
        sink.emit(.workToRest(occurredAt: base, from: "w#1", to: "r#1"))
        sink.emit(.last3s(occurredAt: base, segmentId: "w#1"))
        XCTAssertEqual(collector.events.count, 1)
        XCTAssertEqual(collector.events.first?.kind, .segmentStart)
    }

    func test_allows_next_second_to_emit_again() {
        let collector = Collecting()
        let sink = CueCoalescingSink(collector)
        sink.emit(.segmentStart(occurredAt: Date(timeIntervalSince1970: 100), segmentId: "w#1", kind: .work, setIndex: 1))
        sink.emit(.workToRest(occurredAt: Date(timeIntervalSince1970: 101), from: "w#1", to: "r#1"))
        XCTAssertEqual(collector.events.count, 2)
    }
}
