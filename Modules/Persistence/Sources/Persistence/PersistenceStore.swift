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

/// Portable export/import payload (3.4.2).
///
/// - Note: This is a best-effort backup format. It intentionally excludes audio files and other large assets.
public struct InterfitBackupBundle: Codable, Sendable, Equatable {
    public var formatVersion: Int
    public var schemaVersion: Int
    public var exportedAt: Date

    public var plans: [Plan]
    public var sessions: [Session]
    public var planVersions: [PlanVersion]
    public var recoverableSessionSnapshot: RecoverableSessionSnapshot?

    /// Reserved for app-level settings (owned by the app target, not the Persistence module).
    public var appSettings: [String: String]?

    public init(
        formatVersion: Int = 1,
        schemaVersion: Int,
        exportedAt: Date = Date(),
        plans: [Plan],
        sessions: [Session],
        planVersions: [PlanVersion],
        recoverableSessionSnapshot: RecoverableSessionSnapshot?,
        appSettings: [String: String]? = nil
    ) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.plans = plans
        self.sessions = sessions
        self.planVersions = planVersions
        self.recoverableSessionSnapshot = recoverableSessionSnapshot
        self.appSettings = appSettings
    }
}

public enum InterfitBackupImportError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(found: Int, maxSupported: Int)
}

/// Minimal in-memory no-op store for wiring and tests.
public actor InMemoryPersistenceStore: PersistenceStore {
    public nonisolated let currentSchemaVersion: Int = PersistenceSchemaVersion.current

    private var storedSchemaVersion: Int?
    private var plansById: [UUID: Plan] = [:]
    private var sessionsById: [UUID: Session] = [:]
    private var planVersionsById: [UUID: PlanVersion] = [:]
    private var recoverableSessionSnapshot: RecoverableSessionSnapshot?

    public init() {}

    public func readStoredSchemaVersion() async -> Int? { storedSchemaVersion }

    public func writeStoredSchemaVersion(_ version: Int) async {
        storedSchemaVersion = version
    }

    public func resetAllData() async {
        storedSchemaVersion = nil
        plansById.removeAll()
        sessionsById.removeAll()
        planVersionsById.removeAll()
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
    private let planVersionsDefaultsKey = "interfit.persistence.planVersions"
    private let recoverableSessionDefaultsKey = "interfit.persistence.recoverableSessionSnapshot"
    private let recoverableSessionDecodeFailedAtDefaultsKey = "interfit.persistence.recoverableSessionSnapshot.decodeFailedAt"
    private let recoverableSessionDecodeFailedBytesDefaultsKey = "interfit.persistence.recoverableSessionSnapshot.decodeFailedBytes"
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

    public func resetAllData() async {
        defaults.removeObject(forKey: schemaDefaultsKey)
        defaults.removeObject(forKey: plansDefaultsKey)
        defaults.removeObject(forKey: sessionsDefaultsKey)
        defaults.removeObject(forKey: planVersionsDefaultsKey)
        defaults.removeObject(forKey: recoverableSessionDefaultsKey)
        defaults.removeObject(forKey: recoverableSessionDecodeFailedAtDefaultsKey)
        defaults.removeObject(forKey: recoverableSessionDecodeFailedBytesDefaultsKey)
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

    func loadRecoverableSessionSnapshot() -> RecoverableSessionSnapshot? {
        guard let data = defaults.data(forKey: recoverableSessionDefaultsKey) else { return nil }
        do {
            return try JSONDecoder().decode(RecoverableSessionSnapshot.self, from: data)
        } catch {
            // Treat decode failure as corrupted recovery payload: clear it to avoid repeated recovery prompts,
            // and store a small diagnostic marker so the app can explain what happened if needed.
            defaults.removeObject(forKey: recoverableSessionDefaultsKey)
            defaults.set(Date(), forKey: recoverableSessionDecodeFailedAtDefaultsKey)
            defaults.set(data.count, forKey: recoverableSessionDecodeFailedBytesDefaultsKey)
            return nil
        }
    }

    func saveRecoverableSessionSnapshot(_ snapshot: RecoverableSessionSnapshot?) {
        guard let snapshot else {
            defaults.removeObject(forKey: recoverableSessionDefaultsKey)
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: recoverableSessionDefaultsKey)
        } catch {
            // M0: ignore write errors; higher layers can degrade gracefully.
        }
    }

    func loadPlanVersions() -> [PlanVersion] {
        guard let data = defaults.data(forKey: planVersionsDefaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([PlanVersion].self, from: data)
        } catch {
            return []
        }
    }

    func savePlanVersions(_ versions: [PlanVersion]) {
        do {
            let data = try JSONEncoder().encode(versions)
            defaults.set(data, forKey: planVersionsDefaultsKey)
        } catch {
            // M0/M1: ignore write errors; higher layers can degrade gracefully.
        }
    }
}

// MARK: - Export / Import (3.4.2)

extension InMemoryPersistenceStore {
    public func exportBackupBundle(exportedAt: Date = Date()) async -> InterfitBackupBundle {
        let schema = storedSchemaVersion ?? currentSchemaVersion
        return InterfitBackupBundle(
            schemaVersion: schema,
            exportedAt: exportedAt,
            plans: Array(plansById.values),
            sessions: Array(sessionsById.values),
            planVersions: Array(planVersionsById.values),
            recoverableSessionSnapshot: recoverableSessionSnapshot
        )
    }

    public func importBackupBundle(_ bundle: InterfitBackupBundle, overwrite: Bool = true) async throws {
        if bundle.schemaVersion > currentSchemaVersion {
            throw InterfitBackupImportError.unsupportedSchemaVersion(found: bundle.schemaVersion, maxSupported: currentSchemaVersion)
        }

        if overwrite {
            plansById = Dictionary(uniqueKeysWithValues: bundle.plans.map { ($0.id, $0) })
            sessionsById = Dictionary(uniqueKeysWithValues: bundle.sessions.map { ($0.id, $0) })
            planVersionsById = Dictionary(uniqueKeysWithValues: bundle.planVersions.map { ($0.id, $0) })
            recoverableSessionSnapshot = bundle.recoverableSessionSnapshot
            storedSchemaVersion = bundle.schemaVersion
        } else {
            for plan in bundle.plans { plansById[plan.id] = plan }
            for session in bundle.sessions { sessionsById[session.id] = session }
            for version in bundle.planVersions { planVersionsById[version.id] = version }
            if let snapshot = bundle.recoverableSessionSnapshot { recoverableSessionSnapshot = snapshot }
            storedSchemaVersion = max(storedSchemaVersion ?? 0, bundle.schemaVersion)
        }
    }
}

extension CoreDataPersistenceStore {
    public func exportBackupBundle(exportedAt: Date = Date()) async -> InterfitBackupBundle {
        let stored = await readStoredSchemaVersion()
        let schema = stored ?? currentSchemaVersion
        return InterfitBackupBundle(
            schemaVersion: schema,
            exportedAt: exportedAt,
            plans: loadPlans(),
            sessions: loadSessions(),
            planVersions: loadPlanVersions(),
            recoverableSessionSnapshot: loadRecoverableSessionSnapshot()
        )
    }

    public func importBackupBundle(_ bundle: InterfitBackupBundle, overwrite: Bool = true) async throws {
        if bundle.schemaVersion > currentSchemaVersion {
            throw InterfitBackupImportError.unsupportedSchemaVersion(found: bundle.schemaVersion, maxSupported: currentSchemaVersion)
        }

        // Minimal semantics: overwrite by default (imported bundle is source of truth).
        if overwrite {
            savePlans(bundle.plans)
            saveSessions(bundle.sessions)
            savePlanVersions(bundle.planVersions)
            saveRecoverableSessionSnapshot(bundle.recoverableSessionSnapshot)
            await writeStoredSchemaVersion(bundle.schemaVersion)
            return
        }

        // Merge semantics: upsert by id.
        var plans = loadPlans()
        for plan in bundle.plans {
            if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
                plans[idx] = plan
            } else {
                plans.append(plan)
            }
        }
        savePlans(plans)

        var sessions = loadSessions()
        for session in bundle.sessions {
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = session
            } else {
                sessions.append(session)
            }
        }
        saveSessions(sessions)

        var versions = loadPlanVersions()
        for version in bundle.planVersions {
            if let idx = versions.firstIndex(where: { $0.id == version.id }) {
                versions[idx] = version
            } else {
                versions.append(version)
            }
        }
        savePlanVersions(versions)

        if let snapshot = bundle.recoverableSessionSnapshot {
            saveRecoverableSessionSnapshot(snapshot)
        }
        await writeStoredSchemaVersion(max((await readStoredSchemaVersion()) ?? 0, bundle.schemaVersion))
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
            musicStrategy: existing.musicStrategy,
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
        let plans = loadPlans()
        let clamped = plans.map { $0.clamped() }
        if clamped != plans {
            savePlans(clamped)
        }
        return clamped.sorted { $0.updatedAt > $1.updatedAt }
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
            musicStrategy: existing.musicStrategy,
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

extension InMemoryPersistenceStore: RecoverableSessionRepository {
    public func fetchRecoverableSessionSnapshot() async -> RecoverableSessionSnapshot? {
        recoverableSessionSnapshot
    }

    public func upsertRecoverableSessionSnapshot(_ snapshot: RecoverableSessionSnapshot) async {
        recoverableSessionSnapshot = snapshot
    }

    public func clearRecoverableSessionSnapshot() async {
        recoverableSessionSnapshot = nil
    }
}

extension CoreDataPersistenceStore: RecoverableSessionRepository {
    public func fetchRecoverableSessionSnapshot() async -> RecoverableSessionSnapshot? {
        loadRecoverableSessionSnapshot()
    }

    public func upsertRecoverableSessionSnapshot(_ snapshot: RecoverableSessionSnapshot) async {
        saveRecoverableSessionSnapshot(snapshot)
    }

    public func clearRecoverableSessionSnapshot() async {
        saveRecoverableSessionSnapshot(nil)
    }
}

extension InMemoryPersistenceStore: PlanVersionRepository {
    public func fetchAllPlanVersions() async -> [PlanVersion] {
        planVersionsById.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func fetchPlanVersions(planId: UUID) async -> [PlanVersion] {
        planVersionsById.values
            .filter { $0.planId == planId }
            .sorted { ($0.versionNumber, $0.updatedAt) > ($1.versionNumber, $1.updatedAt) }
    }

    public func upsertPlanVersion(_ version: PlanVersion) async throws {
        if let existing = planVersionsById[version.id], existing.status == .published, existing != version {
            throw PlanVersionRepositoryError.cannotModifyPublishedVersion
        }
        planVersionsById[version.id] = version
    }

    public func deletePlanVersion(id: UUID) async {
        planVersionsById.removeValue(forKey: id)
    }
}

extension CoreDataPersistenceStore: PlanVersionRepository {
    public func fetchAllPlanVersions() async -> [PlanVersion] {
        loadPlanVersions().sorted { $0.updatedAt > $1.updatedAt }
    }

    public func fetchPlanVersions(planId: UUID) async -> [PlanVersion] {
        loadPlanVersions()
            .filter { $0.planId == planId }
            .sorted { ($0.versionNumber, $0.updatedAt) > ($1.versionNumber, $1.updatedAt) }
    }

    public func upsertPlanVersion(_ version: PlanVersion) async throws {
        var versions = loadPlanVersions()
        if let idx = versions.firstIndex(where: { $0.id == version.id }) {
            let existing = versions[idx]
            if existing.status == .published, existing != version {
                throw PlanVersionRepositoryError.cannotModifyPublishedVersion
            }
            versions[idx] = version
        } else {
            versions.append(version)
        }
        savePlanVersions(versions)
    }

    public func deletePlanVersion(id: UUID) async {
        var versions = loadPlanVersions()
        versions.removeAll { $0.id == id }
        savePlanVersions(versions)
    }
}
