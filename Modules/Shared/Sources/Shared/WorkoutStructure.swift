import Foundation

public enum WorkoutSegmentKind: String, Sendable, Codable, CaseIterable {
    case work
    case rest
}

/// A pure (side-effect free) description of an interval workout:
/// Work + Rest repeated for `setsCount` sets, with rest only **between** sets.
///
/// Segment timeline example (sets=3, rest>0):
/// Work(1) → Rest(1) → Work(2) → Rest(2) → Work(3)
///
/// M0 scope: supports `restSeconds = 0` (no rest segments).
public struct WorkoutStructure: Sendable, Equatable {
    public let setsCount: Int
    public let workSeconds: Int
    public let restSeconds: Int

    public init(setsCount: Int, workSeconds: Int, restSeconds: Int) {
        self.setsCount = max(0, setsCount)
        self.workSeconds = max(0, workSeconds)
        self.restSeconds = max(0, restSeconds)
    }

    /// Total seconds if we assume rest happens between sets (i.e. `setsCount - 1` rests).
    public var totalSeconds: Int {
        guard setsCount > 0 else { return 0 }
        let rests = max(0, setsCount - 1)
        return (setsCount * workSeconds) + (rests * restSeconds)
    }

    /// Segment count in the linear timeline. If `restSeconds == 0`, it is `setsCount`.
    /// Otherwise, it is `setsCount * 2 - 1` (no rest after the last set).
    public var segmentCount: Int {
        guard setsCount > 0 else { return 0 }
        return restSeconds > 0 ? (setsCount * 2 - 1) : setsCount
    }

    public func progress(atElapsedSeconds elapsedSeconds: Int) -> WorkoutProgress {
        WorkoutProgress(structure: self, elapsedSeconds: elapsedSeconds)
    }
}

public struct WorkoutProgress: Sendable, Equatable {
    public let totalSeconds: Int
    public let totalSets: Int
    public let elapsedSeconds: Int

    /// Completed work sets (i.e. completed "work" segments).
    public let completedSets: Int

    /// `true` if elapsed time reaches the workout end.
    public let isCompleted: Bool

    /// Current segment, `nil` if completed or `totalSeconds == 0`.
    public let currentSegment: WorkoutSegment?

    /// Remaining seconds in the current segment. 0 if completed.
    public let currentSegmentRemainingSeconds: Int

    /// Elapsed seconds within the current segment. 0 if completed.
    public let currentSegmentElapsedSeconds: Int

    public init(structure: WorkoutStructure, elapsedSeconds: Int) {
        let safeElapsed = max(0, elapsedSeconds)
        self.totalSeconds = structure.totalSeconds
        self.totalSets = structure.setsCount
        self.elapsedSeconds = min(safeElapsed, structure.totalSeconds)

        guard structure.totalSeconds > 0, structure.setsCount > 0 else {
            self.completedSets = structure.setsCount
            self.isCompleted = true
            self.currentSegment = nil
            self.currentSegmentRemainingSeconds = 0
            self.currentSegmentElapsedSeconds = 0
            return
        }

        if safeElapsed >= structure.totalSeconds {
            self.completedSets = structure.setsCount
            self.isCompleted = true
            self.currentSegment = nil
            self.currentSegmentRemainingSeconds = 0
            self.currentSegmentElapsedSeconds = 0
            return
        }

        // Compute by walking the linear timeline:
        // Work(set 1), Rest(set 1), Work(set 2), ...
        var t = safeElapsed
        var completedSets = 0

        for setIndex in 1...structure.setsCount {
            let workDuration = structure.workSeconds
            if workDuration > 0 {
                if t < workDuration {
                    let seg = WorkoutSegment(kind: .work, setIndex: setIndex, durationSeconds: workDuration)
                    self.completedSets = completedSets
                    self.isCompleted = false
                    self.currentSegment = seg
                    self.currentSegmentElapsedSeconds = t
                    self.currentSegmentRemainingSeconds = workDuration - t
                    return
                }
                t -= workDuration
            }
            completedSets += 1

            // No rest after the last set.
            let hasRestAfterThisSet = setIndex < structure.setsCount
            let restDuration = hasRestAfterThisSet ? structure.restSeconds : 0
            if restDuration > 0 {
                if t < restDuration {
                    let seg = WorkoutSegment(kind: .rest, setIndex: setIndex, durationSeconds: restDuration)
                    self.completedSets = completedSets
                    self.isCompleted = false
                    self.currentSegment = seg
                    self.currentSegmentElapsedSeconds = t
                    self.currentSegmentRemainingSeconds = restDuration - t
                    return
                }
                t -= restDuration
            }
        }

        // Fallback (shouldn't happen due to the safeElapsed < totalSeconds guard).
        self.completedSets = structure.setsCount
        self.isCompleted = true
        self.currentSegment = nil
        self.currentSegmentRemainingSeconds = 0
        self.currentSegmentElapsedSeconds = 0
    }
}

public struct WorkoutSegment: Sendable, Equatable {
    public let kind: WorkoutSegmentKind
    /// 1-based set index for this segment.
    public let setIndex: Int
    public let durationSeconds: Int

    public init(kind: WorkoutSegmentKind, setIndex: Int, durationSeconds: Int) {
        self.kind = kind
        self.setIndex = setIndex
        self.durationSeconds = max(0, durationSeconds)
    }
}

