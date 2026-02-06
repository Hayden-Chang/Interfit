import Foundation

public enum MusicStrategyFactory {
    public static func simple(work: MusicSelection?, rest: MusicSelection?) -> MusicStrategy? {
        if work == nil, rest == nil { return nil }
        return MusicStrategy(
            global: nil,
            workCycle: work.map { [$0] } ?? [],
            restCycle: rest.map { [$0] } ?? []
        )
    }

    public static func perSet(workCycle: [MusicSelection], rest: MusicSelection?) -> MusicStrategy? {
        if workCycle.isEmpty, rest == nil { return nil }
        return MusicStrategy(
            global: nil,
            workCycle: workCycle,
            restCycle: rest.map { [$0] } ?? []
        )
    }
}

