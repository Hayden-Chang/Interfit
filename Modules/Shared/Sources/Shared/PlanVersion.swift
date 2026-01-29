import Foundation

public enum PlanVersionStatus: String, Sendable, Codable {
    case draft
    case published
}

/// Immutable plan version record (M1).
/// - Note: Editing should happen on draft; publishing creates a new published version.
public struct PlanVersion: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    /// Logical plan family id that versions belong to.
    public var planId: UUID
    public var status: PlanVersionStatus
    public var versionNumber: Int

    public var setsCount: Int
    public var workSeconds: Int
    public var restSeconds: Int
    public var name: String

    public var createdAt: Date
    public var updatedAt: Date
    public var publishedAt: Date?

    public init(
        id: UUID = UUID(),
        planId: UUID,
        status: PlanVersionStatus,
        versionNumber: Int,
        setsCount: Int,
        workSeconds: Int,
        restSeconds: Int,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.planId = planId
        self.status = status
        self.versionNumber = versionNumber
        self.setsCount = setsCount
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publishedAt = publishedAt
    }
}

public extension PlanVersion {
    /// Stable content hash for deduplication (Apply/Fork).
    ///
    /// - Important: Intentionally excludes metadata fields (id/planId/status/version/dates).
    /// - Note: `name` is excluded so "same workout content" hashes the same even if renamed.
    var contentHash: String {
        ContentHash.sha256Hex("planContent:v1;sets=\(setsCount);work=\(workSeconds);rest=\(restSeconds)")
    }

    /// Total seconds if we assume rest happens between sets (i.e. \(setsCount - 1\) rests).
    var estimatedTotalSeconds: Int {
        let rests = max(0, setsCount - 1)
        return (setsCount * workSeconds) + (rests * restSeconds)
    }
}
