import XCTest
@testable import Shared

final class MusicWarmupPlannerTests: XCTestCase {
    func test_initialAppleMusicSelections_returnsEmptyWhenNoStrategy() {
        XCTAssertEqual(MusicWarmupPlanner.initialAppleMusicSelections(strategy: nil), [])
    }

    func test_initialAppleMusicSelections_prefersFirstWorkRestAndGlobal_inStableOrder() {
        let work = MusicSelection(
            source: .appleMusic,
            type: .track,
            externalId: "work-1",
            displayTitle: "Work One",
            playMode: .continue
        )
        let rest = MusicSelection(
            source: .appleMusic,
            type: .playlist,
            externalId: "rest-1",
            displayTitle: "Rest One",
            playMode: .continue
        )
        let global = MusicSelection(
            source: .appleMusic,
            type: .album,
            externalId: "global-1",
            displayTitle: "Global One",
            playMode: .continue
        )

        let strategy = MusicStrategy(global: global, workCycle: [work], restCycle: [rest])

        XCTAssertEqual(
            MusicWarmupPlanner.initialAppleMusicSelections(strategy: strategy),
            [work, rest, global]
        )
    }

    func test_initialAppleMusicSelections_filtersNonAppleMusicAndDedupesEquivalentSelections() {
        let work = MusicSelection(
            source: .appleMusic,
            type: .track,
            externalId: "shared-id",
            displayTitle: "Work",
            playMode: .continue
        )
        let duplicateRest = MusicSelection(
            source: .appleMusic,
            type: .track,
            externalId: "shared-id",
            displayTitle: "Same Item Different Title",
            playMode: .continue
        )
        let localGlobal = MusicSelection(
            source: .localLibrary,
            type: .track,
            externalId: "library-id",
            displayTitle: "Local",
            playMode: .continue
        )

        let strategy = MusicStrategy(global: localGlobal, workCycle: [work], restCycle: [duplicateRest])

        XCTAssertEqual(
            MusicWarmupPlanner.initialAppleMusicSelections(strategy: strategy),
            [work]
        )
    }
}
