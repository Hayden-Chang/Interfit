import Foundation

public enum BackgroundCueNotificationRefreshAction: Sendable, Equatable {
    case noOp
    case schedule
    case cancel
}

public enum BackgroundCueNotificationRefreshPolicy {
    public static func decide(sessionStatus: SessionStatus?, appIsActive: Bool) -> BackgroundCueNotificationRefreshAction {
        guard let sessionStatus else { return .noOp }
        if sessionStatus == .running && !appIsActive {
            return .schedule
        }
        return .cancel
    }
}
