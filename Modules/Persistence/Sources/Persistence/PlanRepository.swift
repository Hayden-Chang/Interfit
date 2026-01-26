import Foundation
import Shared

/// Plan CRUD abstraction (M0).
public protocol PlanRepository: Sendable {
    func fetchAllPlans() async -> [Plan]
    func fetchRecentPlans(limit: Int) async -> [Plan]

    /// Insert or update by `Plan.id`.
    func upsertPlan(_ plan: Plan) async

    func deletePlan(id: UUID) async

    /// Create a new plan based on an existing one.
    func duplicatePlan(id: UUID, nameOverride: String?) async -> Plan?
}

