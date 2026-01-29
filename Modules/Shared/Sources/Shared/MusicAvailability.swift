import Foundation

public enum MusicAuthorizationState: String, Sendable, Codable, Hashable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public enum MusicAvailabilityIssue: String, Sendable, Codable, Hashable {
    case subscriptionUnavailable
    case resourceUnavailable
}

public enum MusicAvailabilityCTA: String, Sendable, Codable, Hashable {
    case requestPermission
    case openSettings
    case pickDifferentMusic
    case none
}

/// Music availability state machine (2.2.7).
///
/// - Note: This is a pure model. Platform-specific mapping (MusicKit/MediaPlayer) lives outside `Shared`.
public struct MusicAvailability: Sendable, Codable, Hashable {
    public var authorization: MusicAuthorizationState
    public var issues: Set<MusicAvailabilityIssue>

    public init(authorization: MusicAuthorizationState, issues: Set<MusicAvailabilityIssue> = []) {
        self.authorization = authorization
        self.issues = issues
    }

    public var isUsable: Bool {
        authorization == .authorized && issues.isEmpty
    }

    public var cta: MusicAvailabilityCTA {
        switch authorization {
        case .notDetermined:
            return .requestPermission
        case .denied:
            return .openSettings
        case .restricted:
            return .none
        case .authorized:
            if issues.contains(.subscriptionUnavailable) || issues.contains(.resourceUnavailable) {
                return .pickDifferentMusic
            }
            return .none
        }
    }
}

