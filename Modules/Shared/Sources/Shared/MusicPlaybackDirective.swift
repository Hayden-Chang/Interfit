import Foundation

/// Minimal playback directive derived from `MusicPlayMode` (2.2.4).
public enum MusicPlaybackDirective: Sendable, Equatable {
    /// Do not change current playback.
    case none
    /// Restart the current selection on every segment start.
    case restartSelection
    /// Shuffle within the current selection on every segment start.
    case shuffleSelection
}

public extension MusicPlayMode {
    var directiveOnSegmentStart: MusicPlaybackDirective {
        switch self {
        case .continue:
            return .none
        case .restartOnSegment:
            return .restartSelection
        case .shuffleOnSegment:
            return .shuffleSelection
        }
    }
}

