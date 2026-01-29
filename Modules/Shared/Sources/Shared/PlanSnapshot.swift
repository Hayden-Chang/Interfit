import Foundation

/// Immutable plan snapshot captured at Session start (M1).
public struct PlanSnapshot: Sendable, Codable, Equatable {
    public static let currentConfigVersion: Int = 1

    /// Configuration schema version for migration (M1+).
    public var configVersion: Int
    public var planId: UUID?
    public var planVersionId: UUID?

    public var setsCount: Int
    public var workSeconds: Int
    public var restSeconds: Int
    public var name: String

    public var capturedAt: Date

    public init(
        planId: UUID?,
        planVersionId: UUID? = nil,
        setsCount: Int,
        workSeconds: Int,
        restSeconds: Int,
        name: String,
        capturedAt: Date = Date(),
        configVersion: Int = PlanSnapshot.currentConfigVersion
    ) {
        self.configVersion = configVersion
        self.planId = planId
        self.planVersionId = planVersionId
        self.setsCount = setsCount
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.name = name
        self.capturedAt = capturedAt
    }
}

public extension PlanSnapshot {
    var estimatedTotalSeconds: Int {
        let rests = max(0, setsCount - 1)
        return (setsCount * workSeconds) + (rests * restSeconds)
    }
}

// MARK: - Codable (backward compatible)

extension PlanSnapshot {
    enum CodingKeys: String, CodingKey {
        case configVersion
        case planId
        case planVersionId
        case setsCount
        case workSeconds
        case restSeconds
        case name
        case capturedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = PlanSnapshot(
            planId: try container.decodeIfPresent(UUID.self, forKey: .planId),
            planVersionId: try container.decodeIfPresent(UUID.self, forKey: .planVersionId),
            setsCount: try container.decode(Int.self, forKey: .setsCount),
            workSeconds: try container.decode(Int.self, forKey: .workSeconds),
            restSeconds: try container.decode(Int.self, forKey: .restSeconds),
            name: try container.decode(String.self, forKey: .name),
            capturedAt: try container.decode(Date.self, forKey: .capturedAt),
            configVersion: try container.decodeIfPresent(Int.self, forKey: .configVersion) ?? 0
        )
        self = PlanSnapshotMigrator.migrate(decoded).snapshot
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(configVersion, forKey: .configVersion)
        try container.encodeIfPresent(planId, forKey: .planId)
        try container.encodeIfPresent(planVersionId, forKey: .planVersionId)
        try container.encode(setsCount, forKey: .setsCount)
        try container.encode(workSeconds, forKey: .workSeconds)
        try container.encode(restSeconds, forKey: .restSeconds)
        try container.encode(name, forKey: .name)
        try container.encode(capturedAt, forKey: .capturedAt)
    }
}
