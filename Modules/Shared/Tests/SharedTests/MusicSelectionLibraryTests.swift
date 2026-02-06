import XCTest
@testable import Shared

final class MusicSelectionLibraryTests: XCTestCase {
    func test_normalizedPlaylists_filtersDedupesSortsAndLimits() {
        let a1 = MusicSelection(source: .appleMusic, type: .playlist, externalId: "1", displayTitle: "b", playMode: .continue)
        let a2 = MusicSelection(source: .appleMusic, type: .playlist, externalId: "2", displayTitle: "A", playMode: .continue)
        let dup = MusicSelection(source: .appleMusic, type: .playlist, externalId: "1", displayTitle: "b (dup title)", playMode: .continue)
        let nonPlaylist = MusicSelection(source: .appleMusic, type: .track, externalId: "t1", displayTitle: "Track", playMode: .continue)

        let normalized = MusicSelectionLibrary.normalizedPlaylists(from: [a1, a2, dup, nonPlaylist], maxCount: 1)
        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.externalId, "2")
    }
}

