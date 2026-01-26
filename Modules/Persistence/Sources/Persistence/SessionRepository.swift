import Foundation
import Shared

/// Session persistence abstraction (M0).
public protocol SessionRepository: Sendable {
    func fetchAllSessions() async -> [Session]
    func fetchSession(id: UUID) async -> Session?
    func upsertSession(_ session: Session) async
    func deleteSession(id: UUID) async
}

