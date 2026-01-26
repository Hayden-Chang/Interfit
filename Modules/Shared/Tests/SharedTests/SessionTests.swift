import XCTest
@testable import Shared

final class SessionTests: XCTestCase {
    func test_eventKindAndLabel_areStable() {
        let events: [SessionEventRecord] = [
            .segmentChanged(from: "work", to: "rest"),
            .paused(reason: "user"),
            .resumed(),
            .ended(),
            .completed(),
        ]

        XCTAssertEqual(events.compactMap(\.kind), [.segmentChanged, .paused, .resumed, .ended, .completed])
        for event in events {
            XCTAssertFalse(event.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func test_codable_roundTrip_withNilEndedAt() throws {
        let session = Session(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            status: .running,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: nil,
            completedSets: 1,
            totalSets: 4,
            workSeconds: 30,
            restSeconds: 10,
            events: [
                .segmentChanged(occurredAt: Date(timeIntervalSince1970: 11), from: "work", to: "rest"),
                .paused(occurredAt: Date(timeIntervalSince1970: 12), reason: "user"),
            ]
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded, session)
        XCTAssertNil(decoded.endedAt)
        XCTAssertEqual(decoded.events.count, 2)
    }
}

