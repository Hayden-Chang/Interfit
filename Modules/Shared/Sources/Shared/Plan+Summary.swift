import Foundation

public extension Plan {
    /// Build a displayable `Plan` for UI from an immutable `PlanSnapshot`.
    ///
    /// - Note: When `planId` is missing (older data), a new id is generated. The UI
    ///   treats this as display-only and does not assume persistence identity.
    static func from(snapshot: PlanSnapshot) -> Plan {
        Plan(
            id: snapshot.planId ?? UUID(),
            setsCount: snapshot.setsCount,
            workSeconds: snapshot.workSeconds,
            restSeconds: snapshot.restSeconds,
            name: snapshot.name,
            musicStrategy: snapshot.musicStrategy,
            createdAt: snapshot.capturedAt,
            updatedAt: snapshot.capturedAt
        )
    }

    /// Build a best-effort `Plan` for UI display from a `Session`.
    ///
    /// - Important: This is a fallback for cases where the originating `Plan` is not
    ///   available in memory (e.g., recovery/legacy data). It prefers effective
    ///   values (overrides → snapshot → stored session values).
    static func fallbackFrom(session: Session, defaultName: String = "Workout") -> Plan {
        Plan(
            setsCount: session.effectiveSetsCount,
            workSeconds: session.effectiveWorkSeconds,
            restSeconds: session.effectiveRestSeconds,
            name: session.planSnapshot?.name ?? defaultName,
            musicStrategy: session.planSnapshot?.musicStrategy,
            createdAt: session.startedAt,
            updatedAt: session.startedAt
        )
    }
}

