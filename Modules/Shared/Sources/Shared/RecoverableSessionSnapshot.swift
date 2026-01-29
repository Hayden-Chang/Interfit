import Foundation

/// Minimal persisted snapshot for crash/kill recovery (3.2.1).
public struct RecoverableSessionSnapshot: Sendable, Codable, Equatable {
    public var session: Session
    public var elapsedSeconds: Int
    public var capturedAt: Date

    public init(session: Session, elapsedSeconds: Int, capturedAt: Date = Date()) {
        self.session = session
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.capturedAt = capturedAt
    }
}

