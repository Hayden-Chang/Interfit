import Foundation

/// Pure decision helper for segment-boundary playback switching (2.2.9).
///
/// This intentionally contains **no** platform playback code; it only answers:
/// - same selection → do not switch
/// - different selection → switch
public enum PlaybackSelectionAction: Sendable, Equatable {
    case noChange
    case switchSelection(MusicSelection)
}

public enum PlaybackSelectionSwitch {
    public static func decide(current: MusicSelection?, next: MusicSelection?) -> PlaybackSelectionAction {
        guard let next else { return .noChange }
        if let current, current.isEquivalent(to: next) { return .noChange }
        return .switchSelection(next)
    }
}

