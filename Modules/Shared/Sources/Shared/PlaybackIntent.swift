import Foundation

/// High-level playback intent emitted by the training engine.
///
/// The engine only emits **intent**; concrete playback implementations live outside `Shared`.
public enum PlaybackIntent: Sendable, Equatable {
    case segmentChanged(occurredAt: Date, from: String?, to: String, kind: WorkoutSegmentKind, setIndex: Int)
    case paused(occurredAt: Date)
    case resumed(occurredAt: Date)
    case stop(occurredAt: Date)
}

public protocol PlaybackIntentSink: Sendable {
    func emit(_ intent: PlaybackIntent)
}

public struct NoopPlaybackIntentSink: PlaybackIntentSink {
    public init() {}
    public func emit(_ intent: PlaybackIntent) { /* no-op */ }
}
