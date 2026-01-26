import Foundation

public struct WorkoutSegmentIdentity: Sendable, Equatable {
    public let kind: WorkoutSegmentKind
    /// 1-based set index
    public let setIndex: Int

    public init(kind: WorkoutSegmentKind, setIndex: Int) {
        self.kind = kind
        self.setIndex = setIndex
    }

    public var stableId: String {
        "\(kind.rawValue)#\(setIndex)"
    }
}

public struct WorkoutSegmentChange: Sendable, Equatable {
    public let from: WorkoutSegmentIdentity?
    public let to: WorkoutSegmentIdentity

    public init(from: WorkoutSegmentIdentity?, to: WorkoutSegmentIdentity) {
        self.from = from
        self.to = to
    }
}

/// Segment switching scheduler (M0):
/// - Input is elapsed seconds.
/// - Output is a single segment change (if any) and it is emitted at most once per segment.
/// - Completion (no current segment) updates internal state but does not emit `.segmentChanged`.
public struct WorkoutSegmentScheduler: Sendable, Equatable {
    public let structure: WorkoutStructure

    public private(set) var current: WorkoutSegmentIdentity?

    public init(structure: WorkoutStructure) {
        self.structure = structure
        self.current = nil
    }

    /// Update scheduler with latest elapsed seconds.
    ///
    /// - Returns: a segment change if we have entered a new segment; otherwise nil.
    /// - Note: when workout completes (`currentSegment == nil`), this will reset `current` to nil and return nil.
    public mutating func update(elapsedSeconds: Int) -> WorkoutSegmentChange? {
        let progress = structure.progress(atElapsedSeconds: elapsedSeconds)
        let next = progress.currentSegment.map { WorkoutSegmentIdentity(kind: $0.kind, setIndex: $0.setIndex) }

        guard next != current else { return nil }
        let previous = current
        current = next

        guard let next else { return nil }
        return WorkoutSegmentChange(from: previous, to: next)
    }
}

