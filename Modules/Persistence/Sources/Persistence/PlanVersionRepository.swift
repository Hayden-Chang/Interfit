import Foundation
import Shared

public enum PlanVersionRepositoryError: Error, Equatable, Sendable {
    /// Published versions are immutable once written.
    case cannotModifyPublishedVersion
}

/// PlanVersion persistence abstraction (M1).
public protocol PlanVersionRepository: Sendable {
    func fetchAllPlanVersions() async -> [PlanVersion]
    func fetchPlanVersions(planId: UUID) async -> [PlanVersion]

    /// Insert or update by `PlanVersion.id`.
    /// - Note: Updates to existing `.published` versions must be rejected.
    func upsertPlanVersion(_ version: PlanVersion) async throws

    func deletePlanVersion(id: UUID) async
}

