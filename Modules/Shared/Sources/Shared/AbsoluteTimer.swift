import Foundation

/// Drift-resistant timer core based on absolute time (Date), not per-second decrement.
/// 以绝对时间为基准的计时核心（避免“每秒递减”带来的漂移）。
public struct AbsoluteTimer: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case idle
        case running(startedAt: Date)
        case paused(startedAt: Date, pausedAt: Date)
        case ended(startedAt: Date, endedAt: Date)
    }

    public private(set) var state: State = .idle
    public let totalSeconds: Int

    private var accumulatedPauseSeconds: Int = 0

    public init(totalSeconds: Int) {
        self.totalSeconds = max(0, totalSeconds)
    }

    public mutating func start(at now: Date) {
        state = .running(startedAt: now)
        accumulatedPauseSeconds = 0
    }

    public mutating func pause(at now: Date) {
        guard case let .running(startedAt) = state else { return }
        state = .paused(startedAt: startedAt, pausedAt: now)
    }

    public mutating func resume(at now: Date) {
        guard case let .paused(startedAt, pausedAt) = state else { return }
        let pausedDelta = max(0, Int(now.timeIntervalSince(pausedAt)))
        accumulatedPauseSeconds += pausedDelta
        state = .running(startedAt: startedAt)
    }

    public mutating func end(at now: Date) {
        switch state {
        case .idle:
            return
        case let .running(startedAt):
            state = .ended(startedAt: startedAt, endedAt: now)
        case let .paused(startedAt, _):
            state = .ended(startedAt: startedAt, endedAt: now)
        case .ended:
            return
        }
    }

    public func elapsedSeconds(at now: Date) -> Int {
        switch state {
        case .idle:
            0
        case let .running(startedAt):
            max(0, Int(now.timeIntervalSince(startedAt)) - accumulatedPauseSeconds)
        case let .paused(startedAt, pausedAt):
            max(0, Int(pausedAt.timeIntervalSince(startedAt)) - accumulatedPauseSeconds)
        case let .ended(startedAt, endedAt):
            max(0, Int(endedAt.timeIntervalSince(startedAt)) - accumulatedPauseSeconds)
        }
    }

    public func remainingSeconds(at now: Date) -> Int {
        max(0, totalSeconds - elapsedSeconds(at: now))
    }
}

