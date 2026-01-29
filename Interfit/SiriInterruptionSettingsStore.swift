import Foundation
import Shared

enum SiriInterruptionSettingsStore {
    private static let thresholdKey = "interfit.settings.siriPauseThresholdSeconds"

    static var pauseThresholdSeconds: TimeInterval {
        get {
            let v = UserDefaults.standard.object(forKey: thresholdKey) as? NSNumber
            return v?.doubleValue ?? SiriInterruptionPolicy().pauseThresholdSeconds
        }
        set {
            UserDefaults.standard.set(newValue, forKey: thresholdKey)
        }
    }

    static var policy: SiriInterruptionPolicy {
        SiriInterruptionPolicy(pauseThresholdSeconds: pauseThresholdSeconds)
    }
}

