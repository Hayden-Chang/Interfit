import Foundation

public enum PlaybackSegmentStartAction: Sendable, Equatable {
    case noChange
    case switchSelection(MusicSelection, directive: MusicPlaybackDirective)
    case applyDirective(MusicPlaybackDirective)
}

/// Decision helper for what to do at segment start (2.2.9).
///
/// Rules:
/// - next selection is nil → no change
/// - selection changes → switch selection (directive derived from next.playMode)
/// - selection same → apply directive only when playMode asks for it (restart/shuffle)
public enum PlaybackSegmentStartDecision {
    public static func decide(current: MusicSelection?, next: MusicSelection?) -> PlaybackSegmentStartAction {
        guard let next else { return .noChange }
        let directive = next.playMode.directiveOnSegmentStart

        if let current, current.isEquivalent(to: next) {
            return directive == .none ? .noChange : .applyDirective(directive)
        }

        return .switchSelection(next, directive: directive)
    }
}

