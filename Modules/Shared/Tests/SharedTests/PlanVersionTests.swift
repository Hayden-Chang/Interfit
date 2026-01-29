import XCTest
@testable import Shared

final class PlanVersionTests: XCTestCase {
    func testEstimatedTotalSeconds() {
        let version = PlanVersion(
            planId: UUID(),
            status: .draft,
            versionNumber: 1,
            setsCount: 3,
            workSeconds: 10,
            restSeconds: 5,
            name: "Test"
        )
        XCTAssertEqual(version.estimatedTotalSeconds, (3 * 10) + (2 * 5))
    }

    func testCodableRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = PlanVersion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            planId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            status: .published,
            versionNumber: 2,
            setsCount: 6,
            workSeconds: 30,
            restSeconds: 15,
            name: "Demo HIIT v2",
            createdAt: now,
            updatedAt: now,
            publishedAt: now
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PlanVersion.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_contentHash_ignoresNameAndMetadata() {
        let a = PlanVersion(
            id: UUID(),
            planId: UUID(),
            status: .published,
            versionNumber: 2,
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "A",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            publishedAt: Date(timeIntervalSince1970: 3)
        )
        let b = PlanVersion(
            id: UUID(),
            planId: UUID(),
            status: .draft,
            versionNumber: 1,
            setsCount: 5,
            workSeconds: 45,
            restSeconds: 15,
            name: "B (Fork)",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            publishedAt: nil
        )
        XCTAssertEqual(a.contentHash, b.contentHash)
    }

    func test_contentHash_matchesPlanContentHash() {
        let version = PlanVersion(
            planId: UUID(),
            status: .published,
            versionNumber: 1,
            setsCount: 3,
            workSeconds: 30,
            restSeconds: 10,
            name: "V1"
        )
        let plan = Plan(setsCount: 3, workSeconds: 30, restSeconds: 10, name: "Fork")
        XCTAssertEqual(version.contentHash, plan.contentHash)
    }
}
