import Foundation

public enum HeadphoneDisconnectSafetyDecision: Sendable, Equatable {
    case noAction
    /// Require an explicit user resume to avoid unexpected speaker playback.
    case requireSafetyPause
}

/// Minimal safety policy for headphone disconnect (3.1.3).
public struct HeadphoneDisconnectSafetyPolicy: Sendable, Equatable, Codable {
    public init() {}

    public func decide(for event: InterruptionEvent) -> HeadphoneDisconnectSafetyDecision {
        guard event.kind == .routeChanged else { return .noAction }
        guard event.attributes["reason"] == "oldDeviceUnavailable" else { return .noAction }
        return .requireSafetyPause
    }
}

