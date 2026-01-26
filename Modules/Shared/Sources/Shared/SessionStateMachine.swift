import Foundation

public enum PauseReason: String, Sendable, Codable, CaseIterable {
    case user
    case interruption
    case safety
}

public enum SessionTransitionError: Error, Sendable, Equatable {
    case invalidTransition(from: SessionStatus, to: SessionStatus)
}

/// Minimal session state machine (M0).
public struct SessionStateMachine: Sendable, Equatable {
    public private(set) var status: SessionStatus

    public init(status: SessionStatus = .idle) {
        self.status = status
    }

    public mutating func start() throws {
        try transition(to: .running)
    }

    public mutating func pause(reason _: PauseReason) throws {
        try transition(to: .paused)
    }

    public mutating func resume() throws {
        try transition(to: .running)
    }

    public mutating func complete() throws {
        try transition(to: .completed)
    }

    public mutating func end() throws {
        try transition(to: .ended)
    }

    public mutating func transition(to newStatus: SessionStatus) throws {
        guard isAllowed(from: status, to: newStatus) else {
            throw SessionTransitionError.invalidTransition(from: status, to: newStatus)
        }
        status = newStatus
    }

    private func isAllowed(from: SessionStatus, to: SessionStatus) -> Bool {
        switch (from, to) {
        case (.idle, .running):
            true
        case (.running, .paused), (.running, .completed), (.running, .ended):
            true
        case (.paused, .running), (.paused, .ended):
            true
        default:
            false
        }
    }
}

