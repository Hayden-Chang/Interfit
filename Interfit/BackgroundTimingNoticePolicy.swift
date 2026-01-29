import Foundation

enum BackgroundTimingNoticePolicy {
    static let userDefaultsKey = "interfit.notice.backgroundTimingShown"

    static let title = "Background timing"

    static let message =
        "iOS may limit background timing if your device is silent and no continuous audio is playing. " +
        "For best results in background/lock screen, consider enabling music (recommended) or keep the app in the foreground."

    static func shouldShow(hasShown: Bool, isRecovering: Bool) -> Bool {
        guard !hasShown else { return false }
        guard !isRecovering else { return false }
        return true
    }
}

