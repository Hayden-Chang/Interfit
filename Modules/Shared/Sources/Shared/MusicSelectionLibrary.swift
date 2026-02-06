import Foundation

public enum MusicSelectionLibrary {
    /// Normalizes playlist selections for display:
    /// - filters to playlists
    /// - dedupes by `MusicSelection.isEquivalent`
    /// - sorts by `displayTitle` (localized, case-insensitive)
    /// - limits output count
    public static func normalizedPlaylists(
        from selections: [MusicSelection],
        maxCount: Int = 50
    ) -> [MusicSelection] {
        guard maxCount > 0 else { return [] }

        var unique: [MusicSelection] = []
        unique.reserveCapacity(min(selections.count, maxCount))

        for selection in selections where selection.type == .playlist {
            if unique.contains(where: { $0.isEquivalent(to: selection) }) { continue }
            unique.append(selection)
        }

        unique.sort {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }

        if unique.count > maxCount {
            return Array(unique.prefix(maxCount))
        }
        return unique
    }
}

