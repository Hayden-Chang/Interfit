import Foundation
import Shared

enum PlanValidationAdapter {
    static let setsCountRange: ClosedRange<Int> = 1 ... 99
    static let workSecondsRange: ClosedRange<Int> = 10 ... 1800
    static let restSecondsRange: ClosedRange<Int> = 0 ... 1800

    static func validationMessages(for plan: Plan) -> [String] {
        var messages: [String] = []

        if !setsCountRange.contains(plan.setsCount) {
            messages.append("Sets out of range (\(setsCountRange.lowerBound)–\(setsCountRange.upperBound)): \(plan.setsCount)")
        }
        if !workSecondsRange.contains(plan.workSeconds) {
            messages.append("Work seconds out of range (\(workSecondsRange.lowerBound)–\(workSecondsRange.upperBound)): \(plan.workSeconds)")
        }
        if !restSecondsRange.contains(plan.restSeconds) {
            messages.append("Rest seconds out of range (\(restSecondsRange.lowerBound)–\(restSecondsRange.upperBound)): \(plan.restSeconds)")
        }

        return messages
    }

    static func canStart(plan: Plan) -> Bool {
        validationMessages(for: plan).isEmpty
    }
}

