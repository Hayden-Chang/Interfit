import Foundation
import UserNotifications
import Shared

enum SegmentCueNotificationScheduler {

    private static let identifierPrefix = "segmentCue-"

    /// Schedule notifications for all future segment boundaries.
    /// - Parameters:
    ///   - structure: the workout's WorkoutStructure
    ///   - currentElapsed: engine's current elapsed seconds
    static func schedule(structure: WorkoutStructure, currentElapsed: Int) {
        let center = UNUserNotificationCenter.current()
        cancelAll()

        var requests: [UNNotificationRequest] = []
        var boundaryElapsed = 0

        for setIndex in 1...structure.setsCount {
            // Work segment start
            if boundaryElapsed > currentElapsed {
                let delay = TimeInterval(boundaryElapsed - currentElapsed)
                let content = UNMutableNotificationContent()
                content.sound = UNNotificationSound(named: UNNotificationSoundName("work_mp3/set_\(setIndex)_start.mp3"))
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
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("rest_mp3/time_to_rest.mp3"))
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                    let id = "\(identifierPrefix)rest-\(setIndex)"
                    requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
                boundaryElapsed += structure.restSeconds
            }
        }

        for request in requests {
            center.add(request) { _ in }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(identifierPrefix) }.map(\.identifier)
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }
}
