import Foundation
import CoreData
import Shared

/// Persistence abstraction for Interfit.
/// - Note: M0 chooses **Core Data** and starts with a minimal skeleton + schemaVersion.
public protocol PersistenceStore: Sendable {
    var currentSchemaVersion: Int { get }

    func readStoredSchemaVersion() async -> Int?
    func writeStoredSchemaVersion(_ version: Int) async

    func ping() async throws -> Bool
}

public enum PersistenceSchemaVersion {
    public static let current = 1
}

/// Minimal in-memory no-op store for wiring and tests.
public actor InMemoryPersistenceStore: PersistenceStore {
    public nonisolated let currentSchemaVersion: Int = PersistenceSchemaVersion.current

    private var storedSchemaVersion: Int?
    private var plansById: [UUID: Plan] = [:]
    private var sessionsById: [UUID: Session] = [:]

    public init() {}

    public func readStoredSchemaVersion() async -> Int? { storedSchemaVersion }

    public func writeStoredSchemaVersion(_ version: Int) async {
        storedSchemaVersion = version
    }

    public func ping() async throws -> Bool {
        true
    }
}

/// Core Data-backed store skeleton (M0).
/// Implementation details (model/schema/migration) will be expanded in 1.3.2/1.3.3.
public actor CoreDataPersistenceStore: PersistenceStore {
    public nonisolated let currentSchemaVersion: Int = PersistenceSchemaVersion.current

    private let schemaDefaultsKey = "interfit.persistence.schemaVersion"
    private let plansDefaultsKey = "interfit.persistence.plans"
    private let sessionsDefaultsKey = "interfit.persistence.sessions"
    private let defaults: UserDefaults

    public init(userDefaultsSuiteName: String? = nil) {
        if let suite = userDefaultsSuiteName, let ud = UserDefaults(suiteName: suite) {
            self.defaults = ud
        } else {
            self.defaults = .standard
        }
    }

    public func readStoredSchemaVersion() async -> Int? {
        let value = defaults.object(forKey: schemaDefaultsKey) as? NSNumber
        return value?.intValue
    }

    public func writeStoredSchemaVersion(_ version: Int) async {
        defaults.set(version, forKey: schemaDefaultsKey)
    }

    public func ping() async throws -> Bool {
        // Skeleton only: later this will validate Core Data stack health.
        true
    }

    func loadPlans() -> [Plan] {
        guard let data = defaults.data(forKey: plansDefaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([Plan].self, from: data)
        } catch {
            return []
        }
    }

    func savePlans(_ plans: [Plan]) {
        do {
            let data = try JSONEncoder().encode(plans)
            defaults.set(data, forKey: plansDefaultsKey)
        } catch {
            // M0: ignore write errors; higher layers can degrade gracefully.
        }
    }

    func loadSessions() -> [Session] {
        guard let data = defaults.data(forKey: sessionsDefaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([Session].self, from: data)
        } catch {
            return []
        }
    }

    func saveSessions(_ sessions: [Session]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            defaults.set(data, forKey: sessionsDefaultsKey)
        } catch {
            // M0: ignore write errors; higher layers can degrade gracefully.
        }
    }
}

extension InMemoryPersistenceStore: PlanRepository {
    public func fetchAllPlans() async -> [Plan] {
        plansById.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func fetchRecentPlans(limit: Int) async -> [Plan] {
        Array((await fetchAllPlans()).prefix(max(0, limit)))
    }

    public func upsertPlan(_ plan: Plan) async {
        plansById[plan.id] = plan
    }

    public func deletePlan(id: UUID) async {
        plansById.removeValue(forKey: id)
    }

    public func duplicatePlan(id: UUID, nameOverride: String?) async -> Plan? {
        guard let existing = plansById[id] else { return nil }
        let copy = Plan(
            setsCount: existing.setsCount,
            workSeconds: existing.workSeconds,
            restSeconds: existing.restSeconds,
            name: nameOverride ?? (existing.name + " Copy"),
            isFavorite: existing.isFavorite,
            createdAt: Date(),
            updatedAt: Date()
        )
        plansById[copy.id] = copy
        return copy
    }
}

extension CoreDataPersistenceStore: PlanRepository {
    public func fetchAllPlans() async -> [Plan] {
        loadPlans().sorted { $0.updatedAt > $1.updatedAt }
    }

    public func fetchRecentPlans(limit: Int) async -> [Plan] {
        Array((await fetchAllPlans()).prefix(max(0, limit)))
    }

    public func upsertPlan(_ plan: Plan) async {
        var plans = loadPlans()
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        } else {
            plans.append(plan)
        }
        savePlans(plans)
    }

    public func deletePlan(id: UUID) async {
        var plans = loadPlans()
        plans.removeAll { $0.id == id }
        savePlans(plans)
    }

    public func duplicatePlan(id: UUID, nameOverride: String?) async -> Plan? {
        let plans = loadPlans()
        guard let existing = plans.first(where: { $0.id == id }) else { return nil }
        let copy = Plan(
            setsCount: existing.setsCount,
            workSeconds: existing.workSeconds,
            restSeconds: existing.restSeconds,
            name: nameOverride ?? (existing.name + " Copy"),
            isFavorite: existing.isFavorite,
            createdAt: Date(),
            updatedAt: Date()
        )
        await upsertPlan(copy)
        return copy
    }
}

extension InMemoryPersistenceStore: SessionRepository {
    public func fetchAllSessions() async -> [Session] {
        sessionsById.values.sorted { $0.startedAt > $1.startedAt }
    }

    public func fetchSession(id: UUID) async -> Session? {
        sessionsById[id]
    }

    public func upsertSession(_ session: Session) async {
        sessionsById[session.id] = session
    }

    public func deleteSession(id: UUID) async {
        sessionsById.removeValue(forKey: id)
    }
}

extension CoreDataPersistenceStore: SessionRepository {
    public func fetchAllSessions() async -> [Session] {
        loadSessions().sorted { $0.startedAt > $1.startedAt }
    }

    public func fetchSession(id: UUID) async -> Session? {
        loadSessions().first(where: { $0.id == id })
    }

    public func upsertSession(_ session: Session) async {
        var sessions = loadSessions()
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        saveSessions(sessions)
    }

    public func deleteSession(id: UUID) async {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == id }
        saveSessions(sessions)
    }
}
