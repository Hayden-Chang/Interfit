import Foundation

public enum MusicPlaybackErrorPresentation: String, Sendable, Equatable, Codable {
    case unauthorized
    case musicAppUnavailable
    case subscriptionUnavailable
    case configurationError
    case itemUnavailable
    case networkUnavailable
    case unknown

    public var message: String {
        switch self {
        case .unauthorized:
            return "Music access is unavailable. Check Apple Music permissions in Settings."
        case .musicAppUnavailable:
            return "The Apple Music app is not installed on this device. Install Music, then try again."
        case .subscriptionUnavailable:
            return "Apple Music account or subscription is unavailable for playback on this device. Sign in to Media & Purchases and verify Apple Music is active, then try again."
        case .configurationError:
            return "Music playback is unavailable because the app's MusicKit configuration is incomplete."
        case .itemUnavailable:
            return "This song or playlist isn't available for playback right now. Try another selection."
        case .networkUnavailable:
            return "Network unavailable. Check your connection and try again."
        case .unknown:
            return "Couldn't play this right now. Try again or choose another item."
        }
    }

    public var displayName: String {
        switch self {
        case .unauthorized:
            return "Unauthorized"
        case .musicAppUnavailable:
            return "Apple Music app unavailable"
        case .subscriptionUnavailable:
            return "Subscription unavailable"
        case .configurationError:
            return "MusicKit configuration error"
        case .itemUnavailable:
            return "Item unavailable"
        case .networkUnavailable:
            return "Network unavailable"
        case .unknown:
            return "Unknown"
        }
    }

    public static func adjustForEnvironment(
        _ presentation: Self,
        musicAppAvailability: String? = nil,
        subscriptionErrorKind: String? = nil
    ) -> Self {
        guard presentation == .subscriptionUnavailable else { return presentation }

        let normalizedMusicAppAvailability = normalized(musicAppAvailability)
        if normalizedMusicAppAvailability == "missing" {
            return .musicAppUnavailable
        }

        switch normalized(subscriptionErrorKind) {
        case "appunavailable":
            return .musicAppUnavailable
        case "configuration":
            return .configurationError
        default:
            return presentation
        }
    }

    public static func infer(
        fromErrorDescription description: String,
        entitlementStatus: String? = nil,
        authorizationStatus: String? = nil,
        subscriptionAvailable: String? = nil,
        musicAppAvailability: String? = nil,
        subscriptionErrorKind: String? = nil,
        subscriptionErrorDescription: String? = nil
    ) -> Self {
        let lower = description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerSubscriptionErrorDescription = normalized(subscriptionErrorDescription)
        let normalizedMusicAppAvailability = normalized(musicAppAvailability)
        let normalizedSubscriptionErrorKind = normalized(subscriptionErrorKind)

        if containsMusicAppUnavailableClue(in: lower)
            || containsMusicAppUnavailableClue(in: lowerSubscriptionErrorDescription)
        {
            return .musicAppUnavailable
        }

        if normalizedSubscriptionErrorKind == "appunavailable" {
            return .musicAppUnavailable
        }

        if normalizedSubscriptionErrorKind == "configuration" {
            return .configurationError
        }

        if isPrepareToPlayFailure(lower) {
            if normalizedMusicAppAvailability == "missing" {
                return .musicAppUnavailable
            }

            let auth = normalized(authorizationStatus)
            if auth.contains("denied") || auth.contains("restricted") {
                return .unauthorized
            }

            if normalized(subscriptionAvailable) == "false" {
                return .subscriptionUnavailable
            }

            if normalizedSubscriptionErrorKind == "unknown"
                || normalized(subscriptionAvailable) == "unknown"
            {
                return .musicAppUnavailable
            }

            if normalized(entitlementStatus) == "missing" {
                return .configurationError
            }

            return .itemUnavailable
        }

        if lower.contains("client not found")
            || lower.contains("40402")
            || lower.contains("developertokenrequestfailed")
            || lower.contains("developer token")
            || lower.contains("token service")
            || lower.contains("musickit configuration")
        {
            return .configurationError
        }

        if lower.contains("not subscribed")
            || lower.contains("no active subscription")
            || lower.contains("subscription required")
            || lower.contains("music subscription")
            || lower.contains("subscription")
        {
            return .subscriptionUnavailable
        }

        if lower.contains("offline")
            || lower.contains("network")
            || lower.contains("timeout")
            || lower.contains("internet")
            || lower.contains("connection")
        {
            return .networkUnavailable
        }

        if lower.contains("not authorized")
            || lower.contains("authorization")
            || lower.contains("permission")
            || lower.contains("denied")
            || lower.contains("restricted")
        {
            return .unauthorized
        }

        if lower.contains("not found")
            || lower.contains("unavailable")
            || lower.contains("invalid play parameter")
            || lower.contains("can't be played")
            || lower.contains("cannot be played")
        {
            return .itemUnavailable
        }

        return .unknown
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func containsMusicAppUnavailableClue(in lower: String) -> Bool {
        guard !lower.isEmpty else { return false }

        return lower.contains("music app is not installed")
            || lower.contains("apple music app is not installed")
            || lower.contains("music://")
            || lower.contains("application is not installed")
            || lower.contains("app is not installed")
            || lower.contains("no application can open")
            || lower.contains("failed to obtain remoteobject")
            || lower.contains("nil server")
            || (lower.contains("mpmusicplayercontrollererrordomain") && lower.contains("code=10"))
            || (lower.contains("mpmusicplayercontrollererrordomain") && lower.contains("error 10"))
            || (lower.contains("unable to open") && lower.contains("music"))
            || (lower.contains("can't open") && lower.contains("music"))
            || (lower.contains("cannot open") && lower.contains("music"))
    }

    private static func isPrepareToPlayFailure(_ lower: String) -> Bool {
        guard lower.contains("mpmusicplayercontrollererrordomain") else { return false }

        return lower.contains("failed to prepare to play")
            || lower.contains("code=6")
            || lower.contains("error 6")
    }
}
