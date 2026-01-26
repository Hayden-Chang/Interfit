import Foundation

/// Canonical reasons for failures that may need UI explanation.
/// 失败/不可用原因的统一口径（可用于 UI 展示与日志记录）。
public enum ErrorReason: String, Sendable, Codable, CaseIterable {
    // Permissions
    case permissionNotDetermined
    case permissionDenied
    case permissionRestricted

    // Resources
    case resourceUnavailable
    case outOfStorage

    // Networking
    case networkUnavailable
    case networkTimeout

    // Audio / playback
    case playbackConflict
    case audioSessionInterrupted
    case audioRouteChanged

    // Fallback
    case unsupported
    case unknown
}

public extension ErrorReason {
    /// Short user-facing title (keep neutral, non-blaming).
    var title: String {
        switch self {
        case .permissionNotDetermined: "Permission needed"
        case .permissionDenied: "Permission denied"
        case .permissionRestricted: "Permission restricted"
        case .resourceUnavailable: "Resource unavailable"
        case .outOfStorage: "Insufficient storage"
        case .networkUnavailable: "No network"
        case .networkTimeout: "Network timeout"
        case .playbackConflict: "Playback conflict"
        case .audioSessionInterrupted: "Audio interrupted"
        case .audioRouteChanged: "Audio route changed"
        case .unsupported: "Not supported"
        case .unknown: "Something went wrong"
        }
    }

    /// One-line message to help user decide next action.
    var message: String {
        switch self {
        case .permissionNotDetermined:
            "You can continue without this feature, or allow access when you’re ready."
        case .permissionDenied:
            "You can enable it in Settings, or keep training with cues only."
        case .permissionRestricted:
            "This device/account restricts access. You can keep training with cues only."
        case .resourceUnavailable:
            "The requested resource isn’t available right now."
        case .outOfStorage:
            "Free up some storage and try again."
        case .networkUnavailable:
            "Offline is OK—training can continue. Some content may be unavailable."
        case .networkTimeout:
            "Please try again. Training can continue without this feature."
        case .playbackConflict:
            "Another audio session is taking over. Training can continue with cues."
        case .audioSessionInterrupted:
            "Audio was interrupted (e.g., call/alarm). Training can continue or pause safely."
        case .audioRouteChanged:
            "Audio output changed (e.g., headphones). Training can continue; we may pause for safety."
        case .unsupported:
            "This feature isn’t supported on your device."
        case .unknown:
            "Please try again. Training can continue safely."
        }
    }
}

