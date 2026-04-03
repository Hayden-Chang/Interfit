import Foundation

/// Pure helper for selecting which Apple Music items to prewarm before playback begins.
public enum MusicWarmupPlanner {
    public static func initialAppleMusicSelections(strategy: MusicStrategy?) -> [MusicSelection] {
        guard let strategy else { return [] }

        let candidates = [
            strategy.selection(for: .work, setIndex: 1),
            strategy.selection(for: .rest, setIndex: 1),
            strategy.global,
        ]

        var uniqueSelections: [MusicSelection] = []
        for selection in candidates.compactMap({ $0 }) {
            guard selection.source == .appleMusic else { continue }
            guard !uniqueSelections.contains(where: { $0.isEquivalent(to: selection) }) else { continue }
            uniqueSelections.append(selection)
        }

        return uniqueSelections
    }
}
