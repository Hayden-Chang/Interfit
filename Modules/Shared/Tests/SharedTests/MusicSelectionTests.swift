import XCTest
@testable import Shared

final class MusicSelectionTests: XCTestCase {
    func test_equivalence_ignoresDisplayFields() {
        let a = MusicSelection(
            source: .appleMusic,
            type: .playlist,
            externalId: "pl.123",
            displayTitle: "Title A",
            artworkUrl: URL(string: "https://example.com/a.png"),
            playMode: .continue
        )
        let b = MusicSelection(
            source: .appleMusic,
            type: .playlist,
            externalId: "pl.123",
            displayTitle: "Title B",
            artworkUrl: URL(string: "https://example.com/b.png"),
            playMode: .continue
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_equivalence_includesPlayMode() {
        let a = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.123", displayTitle: "X", playMode: .continue)
        let b = MusicSelection(source: .appleMusic, type: .playlist, externalId: "pl.123", displayTitle: "X", playMode: .restartOnSegment)
        XCTAssertNotEqual(a, b)
    }

    func test_codable_roundTrip_preservesDisplayFields() throws {
        let original = MusicSelection(
            source: .localLibrary,
            type: .track,
            externalId: "trk.999",
            displayTitle: "My Song",
            artworkUrl: URL(string: "https://example.com/art.png"),
            playMode: .shuffleOnSegment
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MusicSelection.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayTitle, original.displayTitle)
        XCTAssertEqual(decoded.artworkUrl, original.artworkUrl)
    }
}

