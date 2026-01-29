import Foundation

public enum SessionStatus: String, Sendable, Codable, CaseIterable {
    case idle
    case running
    case paused
    case completed
    case ended
}

/// Lightweight event record for history / debugging (M0).
/// 后续可在不破坏存量数据的前提下，引入更强类型的事件集合。
public struct SessionEventRecord: Sendable, Codable, Equatable {
    public var name: String
    public var occurredAt: Date
    public var attributes: [String: String]

    public init(name: String, occurredAt: Date = Date(), attributes: [String: String] = [:]) {
        self.name = name
        self.occurredAt = occurredAt
        self.attributes = attributes
    }
}

public enum SessionEventKind: String, Sendable, Codable, CaseIterable {
    case segmentChanged
    case paused
    case resumed
    case ended
    case completed
}

public extension SessionEventRecord {
    var kind: SessionEventKind? { SessionEventKind(rawValue: name) }

    /// User-facing label for history chips (keep neutral).
    var label: String {
        switch kind {
        case .segmentChanged: return "Segment"
        case .paused: return "Paused"
        case .resumed: return "Resumed"
        case .ended: return "Ended"
        case .completed: return "Completed"
        case .none:
            switch name {
            case "preflight":
                if let status = attributes["status"] {
                    return "Preflight (\(status))"
                }
                return "Preflight"
            case "interruption": return "Interruption"
            case "degraded":
                if let raw = attributes["reason"], let reason = DegradeReason(rawValue: raw) {
                    return reason.title
                }
                return "Degraded"
            case "musicOverride": return "Music Override"
            case "musicOverrideCleared": return "Music Override Cleared"
            default: return name
            }
        }
    }

    static func segmentChanged(
        occurredAt: Date = Date(),
        from: String? = nil,
        to: String? = nil
    ) -> Self {
        var attrs: [String: String] = [:]
        if let from { attrs["from"] = from }
        if let to { attrs["to"] = to }
        return .init(name: SessionEventKind.segmentChanged.rawValue, occurredAt: occurredAt, attributes: attrs)
    }

    static func paused(occurredAt: Date = Date(), reason: String? = nil) -> Self {
        var attrs: [String: String] = [:]
        if let reason { attrs["reason"] = reason }
        return .init(name: SessionEventKind.paused.rawValue, occurredAt: occurredAt, attributes: attrs)
    }

    static func resumed(occurredAt: Date = Date()) -> Self {
        .init(name: SessionEventKind.resumed.rawValue, occurredAt: occurredAt)
    }

    static func ended(occurredAt: Date = Date()) -> Self {
        .init(name: SessionEventKind.ended.rawValue, occurredAt: occurredAt)
    }

    static func completed(occurredAt: Date = Date()) -> Self {
        .init(name: SessionEventKind.completed.rawValue, occurredAt: occurredAt)
    }
}

/// Minimal Session domain model (M0).
/// 一次训练会话最小领域模型（M0）。
public struct Session: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var status: SessionStatus
    public var startedAt: Date
    public var endedAt: Date?
    public var planSnapshot: PlanSnapshot?
    public var overrides: SessionOverrides?
    public var completedSets: Int
    public var totalSets: Int
    public var workSeconds: Int
    public var restSeconds: Int
    public var events: [SessionEventRecord]

    public init(
        id: UUID = UUID(),
        status: SessionStatus,
        startedAt: Date,
        endedAt: Date? = nil,
        planSnapshot: PlanSnapshot? = nil,
        overrides: SessionOverrides? = nil,
        completedSets: Int,
        totalSets: Int,
        workSeconds: Int,
        restSeconds: Int,
        events: [SessionEventRecord] = []
    ) {
        self.id = id
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.planSnapshot = planSnapshot
        self.overrides = overrides
        self.completedSets = completedSets
        self.totalSets = totalSets
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.events = events
    }
}

public extension Session {
    var hasOverrides: Bool {
        !(overrides?.isEmpty ?? true)
    }

    var effectiveSetsCount: Int {
        overrides?.setsCount ?? planSnapshot?.setsCount ?? totalSets
    }

    var effectiveWorkSeconds: Int {
        overrides?.workSeconds ?? planSnapshot?.workSeconds ?? workSeconds
    }

    var effectiveRestSeconds: Int {
        overrides?.restSeconds ?? planSnapshot?.restSeconds ?? restSeconds
    }
}
