import XCTest
@testable import Shared

final class MusicItemResolverTests: XCTestCase {
    func test_localLibrary_prefersLibraryThenCatalog_thenFallsBackToLibraryTitleArtist() async throws {
        let calls = Locked<[MusicResolutionAttempt]>([])

        let item: String = try await MusicItemResolver.resolve(
            preferredSource: .localLibrary,
            externalId: "id.1",
            displayTitle: "Hello",
            displaySubtitle: "World",
            fetchLibraryById: { _ in
                calls.withLock { $0.append(.libraryById) }
                return nil
            },
            fetchCatalogById: { _ in
                calls.withLock { $0.append(.catalogById) }
                return nil
            },
            fetchLibraryByTitleArtist: { title, artist in
                calls.withLock { $0.append(.libraryByTitleArtist) }
                XCTAssertEqual(title, "Hello")
                XCTAssertEqual(artist, "World")
                return "resolved"
            }
        )

        XCTAssertEqual(item, "resolved")
        XCTAssertEqual(calls.value, [.libraryById, .catalogById, .libraryByTitleArtist])
    }

    func test_appleMusic_prefersCatalogThenLibrary_andDoesNotTryTitleFallback() async throws {
        let calls = Locked<[MusicResolutionAttempt]>([])

        let item: String = try await MusicItemResolver.resolve(
            preferredSource: .appleMusic,
            externalId: "id.1",
            displayTitle: "Hello",
            displaySubtitle: "World",
            fetchLibraryById: { _ in
                calls.withLock { $0.append(.libraryById) }
                return "fromLibrary"
            },
            fetchCatalogById: { _ in
                calls.withLock { $0.append(.catalogById) }
                return nil
            },
            fetchLibraryByTitleArtist: { _, _ in
                calls.withLock { $0.append(.libraryByTitleArtist) }
                return "shouldNotHappen"
            }
        )

        XCTAssertEqual(item, "fromLibrary")
        XCTAssertEqual(calls.value, [.catalogById, .libraryById])
    }

    func test_stopsAfterFirstSuccessfulAttempt() async throws {
        let calls = Locked<[MusicResolutionAttempt]>([])

        let item: String = try await MusicItemResolver.resolve(
            preferredSource: .localLibrary,
            externalId: "id.1",
            displayTitle: "Hello",
            displaySubtitle: nil,
            fetchLibraryById: { _ in
                calls.withLock { $0.append(.libraryById) }
                return "hit"
            },
            fetchCatalogById: { _ in
                calls.withLock { $0.append(.catalogById) }
                XCTFail("Should not reach catalog when library-by-id succeeds.")
                return nil
            },
            fetchLibraryByTitleArtist: { _, _ in
                calls.withLock { $0.append(.libraryByTitleArtist) }
                XCTFail("Should not reach title/artist fallback when library-by-id succeeds.")
                return nil
            }
        )

        XCTAssertEqual(item, "hit")
        XCTAssertEqual(calls.value, [.libraryById])
    }

    func test_notFound_includesAttemptTrace() async {
        do {
            _ = try await MusicItemResolver.resolve(
                preferredSource: .localLibrary,
                externalId: "id.1",
                displayTitle: "Hello",
                displaySubtitle: "World",
                fetchLibraryById: { _ in nil },
                fetchCatalogById: { _ in nil },
                fetchLibraryByTitleArtist: { _, _ in nil }
            ) as String
            XCTFail("Expected notFound error.")
        } catch let err as MusicResolutionError {
            XCTAssertEqual(err, .notFound(attempts: [.libraryById, .catalogById, .libraryByTitleArtist]))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

