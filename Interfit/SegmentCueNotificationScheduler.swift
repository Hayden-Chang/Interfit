import Foundation
import UserNotifications
import Shared

enum SegmentCueNotificationScheduler {

    private static let identifierPrefix = "segmentCue-"
    private static let maxSets = 99
    private static let maxNumberedSetVoice = 20

    /// Schedule notifications for all future segment boundaries.
    /// - Parameters:
    ///   - structure: the workout's WorkoutStructure
    ///   - currentElapsed: engine's current elapsed seconds
    static func schedule(structure: WorkoutStructure, currentElapsed: Int) {
        let center = UNUserNotificationCenter.current()

        // Cancel synchronously by known IDs (avoids async race condition)
        center.removePendingNotificationRequests(withIdentifiers: allPossibleIdentifiers())

        var requests: [UNNotificationRequest] = []
        var boundaryElapsed = 0

        for setIndex in 1...structure.setsCount {
            // Work segment start
            if boundaryElapsed > currentElapsed {
                let delay = TimeInterval(boundaryElapsed - currentElapsed)
                let content = UNMutableNotificationContent()
                content.sound = workStartSound(for: setIndex)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let id = "\(identifierPrefix)work-\(setIndex)"
                requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
            boundaryElapsed += structure.workSeconds

            // Rest segment start (no rest after last set)
            if setIndex < structure.setsCount, structure.restSeconds > 0 {
                if boundaryElapsed > currentElapsed {
                    let delay = TimeInterval(boundaryElapsed - currentElapsed)
                    let content = UNMutableNotificationContent()
                    content.sound = restStartSound()
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                    let id = "\(identifierPrefix)rest-\(setIndex)"
                    requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
                boundaryElapsed += structure.restSeconds
            }
        }

        for request in requests {
            center.add(request) { error in
                guard let error else { return }
                #if DEBUG
                print("[SegmentCueNotificationScheduler] Failed to add \(request.identifier): \(error)")
                #endif
            }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allPossibleIdentifiers())
    }

    private static func allPossibleIdentifiers() -> [String] {
        var ids: [String] = []
        for setIndex in 1...maxSets {
            ids.append("\(identifierPrefix)work-\(setIndex)")
            ids.append("\(identifierPrefix)rest-\(setIndex)")
        }
        return ids
    }

    private static func workStartSound(for setIndex: Int) -> UNNotificationSound {
        guard setIndex <= maxNumberedSetVoice else {
            return .default
        }
        return sound(named: "set_\(setIndex)_start.caf")
    }

    private static func restStartSound() -> UNNotificationSound {
        sound(named: "time_to_rest.caf")
    }

    private static func sound(named filename: String) -> UNNotificationSound {
        if Bundle.main.url(forResource: filename, withExtension: nil) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(filename))
        }
        return .default
    }
}
