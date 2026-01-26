import Foundation

/// Coalesces cue events within the same wall-clock second to avoid noisy bursts.
/// Segment changes are naturally prioritized because the engine emits `.segmentStart`
/// before transition/last3s cues at the same boundary.
public final class CueCoalescingSink: @unchecked Sendable, CueSink {
    private let downstream: CueSink
    private var lastEmittedSecond: Int?

    public init(_ downstream: CueSink) {
        self.downstream = downstream
        self.lastEmittedSecond = nil
    }

    public func emit(_ event: CueEventRecord) {
        let sec = Int(event.occurredAt.timeIntervalSince1970)
        if lastEmittedSecond == sec {
            // Drop subsequent cues within the same second
            return
        }
        lastEmittedSecond = sec
        downstream.emit(event)
    }
}
