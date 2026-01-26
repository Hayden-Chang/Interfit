import XCTest
@testable import Shared

final class CueEventTests: XCTestCase {
    func test_helperFactories_produceExpectedKindsAndAttributes() throws {
        let t0 = Date(timeIntervalSince1970: 0)
        let segStart = CueEventRecord.segmentStart(occurredAt: t0, segmentId: "work#1", kind: .work, setIndex: 1)
        XCTAssertEqual(segStart.kind, .segmentStart)
        XCTAssertEqual(segStart.attributes["segment"], "work#1")
        XCTAssertEqual(segStart.attributes["kind"], "work")
        XCTAssertEqual(segStart.attributes["set"], "1")

        let w2r = CueEventRecord.workToRest(occurredAt: t0, from: "work#1", to: "rest#1")
        XCTAssertEqual(w2r.kind, .workToRest)
        XCTAssertEqual(w2r.attributes["from"], "work#1")
        XCTAssertEqual(w2r.attributes["to"], "rest#1")

        let r2w = CueEventRecord.restToWork(occurredAt: t0, from: "rest#1", to: "work#2")
        XCTAssertEqual(r2w.kind, .restToWork)
        XCTAssertEqual(r2w.attributes["from"], "rest#1")
        XCTAssertEqual(r2w.attributes["to"], "work#2")

        let l3 = CueEventRecord.last3s(occurredAt: t0, segmentId: "work#1")
        XCTAssertEqual(l3.kind, .last3s)
        XCTAssertEqual(l3.attributes["segment"], "work#1")

        XCTAssertEqual(CueEventRecord.paused(occurredAt: t0).kind, .paused)
        XCTAssertEqual(CueEventRecord.resumed(occurredAt: t0).kind, .resumed)
        XCTAssertEqual(CueEventRecord.completed(occurredAt: t0).kind, .completed)
    }

    func test_codable_roundTrip() throws {
        let event = CueEventRecord.segmentStart(occurredAt: Date(timeIntervalSince1970: 123), segmentId: "rest#1", kind: .rest, setIndex: 1)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CueEventRecord.self, from: data)
        XCTAssertEqual(event, decoded)
    }
}
