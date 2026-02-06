import Foundation

/// Music strategy attached to a plan/session (2.2.5).
///
/// - Global: default selection used when cycle is unavailable.
/// - Cycle: per-segment-kind sequences; setIndex `i` picks `i % n` (1-based input).
public struct MusicStrategy: Sendable, Codable, Equatable, Hashable {
    public var global: MusicSelection?
    public var workCycle: [MusicSelection]
    public var restCycle: [MusicSelection]

    public init(
        global: MusicSelection? = nil,
        workCycle: [MusicSelection] = [],
        restCycle: [MusicSelection] = []
    ) {
        self.global = global
        self.workCycle = workCycle
        self.restCycle = restCycle
    }

    public func selection(for kind: WorkoutSegmentKind, setIndex: Int) -> MusicSelection? {
        let cycle: [MusicSelection]
        switch kind {
        case .work: cycle = workCycle
        case .rest: cycle = restCycle
        }

        if !cycle.isEmpty {
            let idx = max(0, setIndex - 1) % cycle.count
            return cycle[idx]
        }

        return global
    }
}
