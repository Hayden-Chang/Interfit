import XCTest
@testable import Shared

final class PlanTests: XCTestCase {
    func test_restCanBeZero() {
        let plan = Plan(
            setsCount: 4,
            workSeconds: 30,
            restSeconds: 0,
            name: "30s x4 (no rest)"
        )
        XCTAssertEqual(plan.restSeconds, 0)
        XCTAssertEqual(plan.estimatedTotalSeconds, 120)
    }

    func test_codable_roundTrip() throws {
        let plan = Plan(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "Template",
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)
        XCTAssertEqual(decoded, plan)
    }

    func test_decode_withoutOptionalForkFields_defaultsToNil() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "setsCount": 5,
          "workSeconds": 45,
          "restSeconds": 15,
          "name": "Template",
          "isFavorite": true,
          "createdAt": 0,
          "updatedAt": 0
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)
        XCTAssertNil(decoded.forkedFromVersionId)
        XCTAssertNil(decoded.sourcePostId)
    }

    func test_contentHash_ignoresNameAndMetadata() {
        let a = Plan(
            id: UUID(),
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "A",
            isFavorite: false,
            forkedFromVersionId: UUID(),
            sourcePostId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let b = Plan(
            id: UUID(),
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "B (Fork)",
            isFavorite: true,
            forkedFromVersionId: nil,
            sourcePostId: nil,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(a.contentHash, b.contentHash)
    }

    func test_contentHash_changesWhenContentChanges() {
        let a = Plan(setsCount: 5, workSeconds: 45, restSeconds: 15, name: "X")
        let b = Plan(setsCount: 6, workSeconds: 45, restSeconds: 15, name: "X")
        XCTAssertNotEqual(a.contentHash, b.contentHash)
    }
}
