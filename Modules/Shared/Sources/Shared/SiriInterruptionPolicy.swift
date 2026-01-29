import Foundation

public enum SiriInterruptionDecision: Sendable, Equatable {
    case ignore
    case pause
}

/// Siri threshold behavior (3.1.2).
public struct SiriInterruptionPolicy: Sendable, Equatable, Codable {
    public var pauseThresholdSeconds: TimeInterval

    public init(pauseThresholdSeconds: TimeInterval = 3) {
        self.pauseThresholdSeconds = pauseThresholdSeconds
    }

    public func decide(durationSeconds: TimeInterval) -> SiriInterruptionDecision {
        durationSeconds > pauseThresholdSeconds ? .pause : .ignore
    }
}

