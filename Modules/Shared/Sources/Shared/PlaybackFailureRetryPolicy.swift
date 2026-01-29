import Foundation

public enum PlaybackFailureKind: String, Sendable, Codable, Equatable {
    case permission
    case restriction
    case resource
    case offline
    case playbackConflict
    case timeout
    case unknown

    public var degradeReason: DegradeReason {
        switch self {
        case .permission: .fallbackDueToPermission
        case .restriction: .fallbackDueToRestriction
        case .resource: .fallbackDueToResource
        case .offline: .fallbackDueToOffline
        case .playbackConflict: .fallbackDueToPlaybackConflict
        case .timeout: .fallbackDueToOffline
        case .unknown: .unknown
        }
    }
}

public enum PlaybackFailureRetryDecision: Sendable, Equatable {
    case retry(afterSeconds: Double)
    case fallback(PlaybackFailureOutcome)
}

public struct PlaybackFailureRetryContext: Sendable, Equatable {
    /// 0-based attempt number for the current failure.
    public var attempt: Int
    public var kind: PlaybackFailureKind
    public var hasCurrentPlayback: Bool
    public var cuesEnabled: Bool

    public init(attempt: Int, kind: PlaybackFailureKind, hasCurrentPlayback: Bool, cuesEnabled: Bool) {
        self.attempt = max(0, attempt)
        self.kind = kind
        self.hasCurrentPlayback = hasCurrentPlayback
        self.cuesEnabled = cuesEnabled
    }
}

/// Minimal retry+fallback policy (3.3.2).
///
/// Goal: keep segment switching stable; retries must not block the training engine.
public enum PlaybackFailureRetryPolicy {
    /// Fast retries are limited to 1–2 attempts; beyond that, we fall back safely.
    public static func decide(context: PlaybackFailureRetryContext) -> PlaybackFailureRetryDecision {
        if shouldFastRetry(kind: context.kind), context.attempt < 2 {
            let delay = context.attempt == 0 ? 0.15 : 0.35
            return .retry(afterSeconds: delay)
        }

        let fallback = PlaybackFailureFallback.decide(
            context: .init(
                hasCurrentPlayback: context.hasCurrentPlayback,
                cuesEnabled: context.cuesEnabled
            )
        )
        return .fallback(.init(action: fallback.action, degradeReason: context.kind.degradeReason))
    }

    private static func shouldFastRetry(kind: PlaybackFailureKind) -> Bool {
        switch kind {
        case .offline, .timeout, .unknown:
            return true
        case .permission, .restriction, .resource, .playbackConflict:
            return false
        }
    }
}

