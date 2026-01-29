import Foundation

public enum PlaybackFailureAction: Sendable, Equatable {
    /// Keep current music playing; training continues.
    case continueCurrent
    /// Fall back to cues-only (no background music).
    case cuesOnly
    /// No audio at all (last-resort).
    case silence
}

public struct PlaybackFailureOutcome: Sendable, Equatable {
    public var action: PlaybackFailureAction
    public var degradeReason: DegradeReason

    public init(action: PlaybackFailureAction, degradeReason: DegradeReason) {
        self.action = action
        self.degradeReason = degradeReason
    }
}

public struct PlaybackFailureContext: Sendable, Equatable {
    public var hasCurrentPlayback: Bool
    public var cuesEnabled: Bool

    public init(hasCurrentPlayback: Bool, cuesEnabled: Bool) {
        self.hasCurrentPlayback = hasCurrentPlayback
        self.cuesEnabled = cuesEnabled
    }
}

/// Minimal failure fallback policy (2.2.10).
public enum PlaybackFailureFallback {
    public static func decide(context: PlaybackFailureContext) -> PlaybackFailureOutcome {
        if context.hasCurrentPlayback {
            return .init(action: .continueCurrent, degradeReason: .fallbackDueToResource)
        }
        if context.cuesEnabled {
            return .init(action: .cuesOnly, degradeReason: .fallbackDueToResource)
        }
        return .init(action: .silence, degradeReason: .fallbackDueToResource)
    }
}

