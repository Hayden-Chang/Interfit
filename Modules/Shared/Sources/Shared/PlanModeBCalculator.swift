import Foundation

public struct PlanModeBInput: Sendable, Equatable {
    public var totalSeconds: Int
    public var setsCount: Int
    public var workPart: Int
    public var restPart: Int

    public init(totalSeconds: Int, setsCount: Int, workPart: Int, restPart: Int) {
        self.totalSeconds = totalSeconds
        self.setsCount = setsCount
        self.workPart = workPart
        self.restPart = restPart
    }
}

public struct PlanModeBOutput: Sendable, Equatable {
    public var workSeconds: Int
    public var restSeconds: Int
    /// Computed total based on the returned work/rest seconds.
    public var effectiveTotalSeconds: Int

    public init(workSeconds: Int, restSeconds: Int, effectiveTotalSeconds: Int) {
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.effectiveTotalSeconds = effectiveTotalSeconds
    }
}

public enum PlanModeBCalculator {
    /// Computes a suggested constant `workSeconds`/`restSeconds` from a target total duration + sets + ratio.
    ///
    /// - Note: Because `workSeconds`/`restSeconds` must be integers and constant across sets, the computed
    ///   `effectiveTotalSeconds` may be <= `totalSeconds`.
    public static func compute(_ input: PlanModeBInput) -> PlanModeBOutput? {
        let total = input.totalSeconds
        let sets = input.setsCount
        let a = input.workPart
        let b = input.restPart
        let rests = max(0, sets - 1)

        guard total > 0, sets > 0 else { return nil }
        guard a > 0, b >= 0 else { return nil }

        if b == 0 {
            let work = max(0, total / sets)
            let effective = (sets * work)
            return PlanModeBOutput(workSeconds: work, restSeconds: 0, effectiveTotalSeconds: effective)
        }

        // Rational approximation:
        // total ~= sets*w + rests*r
        // ratio: w:r = a:b => r = w*b/a
        // => total ~= w * (sets + rests*b/a) = w * (sets*a + rests*b) / a
        // => w ~= total*a / (sets*a + rests*b)
        let denom = (sets * a) + (rests * b)
        guard denom > 0 else { return nil }
        let work = max(0, (total * a) / denom)
        let rest = max(0, (work * b) / a)
        let effective = (sets * work) + (rests * rest)
        return PlanModeBOutput(workSeconds: work, restSeconds: rest, effectiveTotalSeconds: effective)
    }
}

