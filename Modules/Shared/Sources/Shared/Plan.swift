import Foundation

/// Minimal Plan domain model (M0).
/// 训练计划最小领域模型（M0）。
public struct Plan: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var setsCount: Int
    public var workSeconds: Int
    public var restSeconds: Int
    public var name: String
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        setsCount: Int,
        workSeconds: Int,
        restSeconds: Int,
        name: String,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.setsCount = setsCount
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.name = name
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension Plan {
    /// Total seconds if we assume rest happens between sets (i.e. \(setsCount - 1\) rests).
    var estimatedTotalSeconds: Int {
        let rests = max(0, setsCount - 1)
        return (setsCount * workSeconds) + (rests * restSeconds)
    }
}

