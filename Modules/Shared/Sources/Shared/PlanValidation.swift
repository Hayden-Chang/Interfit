import Foundation

public enum PlanValidationIssue: Sendable, Equatable {
    case setsCountOutOfRange(min: Int, max: Int, actual: Int)
    case workSecondsOutOfRange(min: Int, max: Int, actual: Int)
    case restSecondsOutOfRange(min: Int, max: Int, actual: Int)
}

public struct PlanParameterBounds: Sendable, Equatable {
    public var setsCount: ClosedRange<Int>
    public var workSeconds: ClosedRange<Int>
    public var restSeconds: ClosedRange<Int>

    public init(
        setsCount: ClosedRange<Int>,
        workSeconds: ClosedRange<Int>,
        restSeconds: ClosedRange<Int>
    ) {
        self.setsCount = setsCount
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
    }
}

public extension PlanParameterBounds {
    /// Recommended bounds from `design_all_phases_integrated.md` 5.3.3.
    static let recommended = PlanParameterBounds(
        setsCount: 1 ... 99,
        workSeconds: 10 ... 1800,
        restSeconds: 0 ... 1800
    )
}

public extension Plan {
    func validate(bounds: PlanParameterBounds = .recommended) -> [PlanValidationIssue] {
        var issues: [PlanValidationIssue] = []

        if !bounds.setsCount.contains(setsCount) {
            issues.append(.setsCountOutOfRange(min: bounds.setsCount.lowerBound, max: bounds.setsCount.upperBound, actual: setsCount))
        }
        if !bounds.workSeconds.contains(workSeconds) {
            issues.append(.workSecondsOutOfRange(min: bounds.workSeconds.lowerBound, max: bounds.workSeconds.upperBound, actual: workSeconds))
        }
        if !bounds.restSeconds.contains(restSeconds) {
            issues.append(.restSecondsOutOfRange(min: bounds.restSeconds.lowerBound, max: bounds.restSeconds.upperBound, actual: restSeconds))
        }

        return issues
    }
}
