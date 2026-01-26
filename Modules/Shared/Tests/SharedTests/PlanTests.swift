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
}

