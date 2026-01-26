import Foundation

/// Canonical reasons for graceful degradation (feature fallback) that may be shown to users.
/// 功能降级原因统一口径（用于 UI 展示与日志记录）。
public enum DegradeReason: String, Sendable, Codable, CaseIterable {
    // Permissions / policies
    case fallbackDueToPermission
    case fallbackDueToRestriction

    // Resources / system
    case fallbackDueToResource
    case fallbackDueToInterruption
    case fallbackDueToRouteChange

    // Networking
    case fallbackDueToOffline

    // Playback
    case fallbackDueToPlaybackConflict

    // Generic
    case unknown
}

public extension DegradeReason {
    var title: String {
        switch self {
        case .fallbackDueToPermission: "Using a simpler mode"
        case .fallbackDueToRestriction: "Using a simpler mode"
        case .fallbackDueToResource: "Using a simpler mode"
        case .fallbackDueToInterruption: "Paused for safety"
        case .fallbackDueToRouteChange: "Paused for safety"
        case .fallbackDueToOffline: "Offline mode"
        case .fallbackDueToPlaybackConflict: "Using cues only"
        case .unknown: "Using a simpler mode"
        }
    }

    var message: String {
        switch self {
        case .fallbackDueToPermission:
            "You can keep training with cues. You can enable access later in Settings."
        case .fallbackDueToRestriction:
            "This device/account restricts access. Training continues with cues."
        case .fallbackDueToResource:
            "We couldn’t use this resource right now. Training continues with cues."
        case .fallbackDueToInterruption:
            "We paused to keep things predictable. Resume when you’re ready."
        case .fallbackDueToRouteChange:
            "Audio output changed. Resume to avoid unexpected loud playback."
        case .fallbackDueToOffline:
            "You’re offline. Training continues; online content may be limited."
        case .fallbackDueToPlaybackConflict:
            "Another app is controlling audio. Training continues with cues."
        case .unknown:
            "Training continues safely with a simpler mode."
        }
    }
}

