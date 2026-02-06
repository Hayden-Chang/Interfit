import Foundation

public enum PlanSnapshotMigrationError: Error, Sendable, Equatable, LocalizedError {
    case unsupportedFutureVersion(found: Int, supportedCurrent: Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFutureVersion(found, supportedCurrent):
            return "Unsupported snapshot configVersion=\(found) (current=\(supportedCurrent))."
        }
    }
}

public struct PlanSnapshotMigrationOutcome: Sendable, Equatable {
    public var snapshot: PlanSnapshot
    public var didMigrate: Bool
    public var error: PlanSnapshotMigrationError?

    public init(snapshot: PlanSnapshot, didMigrate: Bool, error: PlanSnapshotMigrationError?) {
        self.snapshot = snapshot
        self.didMigrate = didMigrate
        self.error = error
    }
}

/// Snapshot config migration chain (pure, idempotent, copy-on-write).
public enum PlanSnapshotMigrator {
    public static let currentVersion: Int = PlanSnapshot.currentConfigVersion

    public static func migrate(_ snapshot: PlanSnapshot) -> PlanSnapshotMigrationOutcome {
        if snapshot.configVersion > currentVersion {
            return PlanSnapshotMigrationOutcome(
                snapshot: snapshot,
                didMigrate: false,
                error: .unsupportedFutureVersion(found: snapshot.configVersion, supportedCurrent: currentVersion)
            )
        }

        var current = snapshot
        var didMigrate = false
        var version = snapshot.configVersion

        while version < currentVersion {
            switch version {
            case 0:
                current = migrateV0ToV1(current)
                version = 1
                didMigrate = true
            case 1:
                current = migrateV1ToV2(current)
                version = 2
                didMigrate = true
            default:
                var bumped = current
                bumped.configVersion = currentVersion
                current = bumped
                version = currentVersion
                didMigrate = true
            }
        }

        return PlanSnapshotMigrationOutcome(snapshot: current, didMigrate: didMigrate, error: nil)
    }

    private static func migrateV0ToV1(_ snapshot: PlanSnapshot) -> PlanSnapshot {
        var migrated = snapshot
        migrated.configVersion = 1
        return migrated
    }

    private static func migrateV1ToV2(_ snapshot: PlanSnapshot) -> PlanSnapshot {
        var migrated = snapshot
        migrated.configVersion = 2
        return migrated
    }
}
