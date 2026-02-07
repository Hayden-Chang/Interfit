import Foundation

#if os(iOS)
import UIKit

@MainActor
enum IdleTimerClient {
    static func setDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
#else

@MainActor
enum IdleTimerClient {
    static func setDisabled(_ disabled: Bool) {
        _ = disabled
    }
}
#endif

