import Foundation

extension Notification.Name {
    static let interfitTerminateCurrentTrainingForReplacement = Notification.Name("interfit.training.terminateForReplacement")
    static let interfitCurrentTrainingDidTerminateForReplacement = Notification.Name("interfit.training.didTerminateForReplacement")
    static let interfitCurrentTrainingDidReachTerminalState = Notification.Name("interfit.training.didReachTerminalState")
}
