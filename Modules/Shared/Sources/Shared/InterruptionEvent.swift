import Foundation

/// Unified interruption/route-change model (3.1.1).
public enum InterruptionKind: String, Sendable, Codable, CaseIterable, Hashable {
    case audioSessionInterruptionBegan
    case audioSessionInterruptionEnded
    case routeChanged
    case call
    case alarm
    case siri
    case otherAppTookOverAudio
}

public struct InterruptionEvent: Sendable, Codable, Equatable, Hashable {
    public var kind: InterruptionKind
    public var occurredAt: Date
    public var attributes: [String: String]

    public init(kind: InterruptionKind, occurredAt: Date = Date(), attributes: [String: String] = [:]) {
        self.kind = kind
        self.occurredAt = occurredAt
        self.attributes = attributes
    }

    public var recommendedPauseReason: PauseReason? {
        switch kind {
        case .audioSessionInterruptionBegan, .call, .alarm, .siri, .otherAppTookOverAudio:
            return .interruption
        case .routeChanged:
            return .safety
        case .audioSessionInterruptionEnded:
            return nil
        }
    }

    public var recommendedDegradeReason: DegradeReason? {
        switch kind {
        case .routeChanged:
            return .fallbackDueToRouteChange
        case .audioSessionInterruptionBegan, .audioSessionInterruptionEnded, .call, .alarm, .siri, .otherAppTookOverAudio:
            return .fallbackDueToInterruption
        }
    }

    public func asSessionEventRecord() -> SessionEventRecord {
        var attrs = attributes
        attrs["kind"] = kind.rawValue
        return .init(name: "interruption", occurredAt: occurredAt, attributes: attrs)
    }
}

