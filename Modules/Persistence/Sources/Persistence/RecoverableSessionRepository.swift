import Foundation
import Shared

/// Persistence for crash/kill recovery (3.2.1).
public protocol RecoverableSessionRepository: Sendable {
    func fetchRecoverableSessionSnapshot() async -> RecoverableSessionSnapshot?
    func upsertRecoverableSessionSnapshot(_ snapshot: RecoverableSessionSnapshot) async
    func clearRecoverableSessionSnapshot() async
}

