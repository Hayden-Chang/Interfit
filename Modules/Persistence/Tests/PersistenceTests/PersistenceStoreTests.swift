import XCTest
@testable import Persistence

final class PersistenceStoreTests: XCTestCase {
    func test_inMemoryStore_ping_returnsTrue() async throws {
        let store = InMemoryPersistenceStore()
        let ok = try await store.ping()
        XCTAssertTrue(ok)
    }

    func test_inMemoryStore_schemaVersion_canReadWrite() async {
        let store = InMemoryPersistenceStore()
        let v0 = await store.readStoredSchemaVersion()
        XCTAssertNil(v0)
        await store.writeStoredSchemaVersion(123)
        let v1 = await store.readStoredSchemaVersion()
        XCTAssertEqual(v1, 123)
        XCTAssertEqual(store.currentSchemaVersion, PersistenceSchemaVersion.current)
    }
}

