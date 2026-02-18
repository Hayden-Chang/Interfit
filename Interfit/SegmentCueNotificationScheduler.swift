import Foundation
import UserNotifications
import Shared
#if os(iOS)
import UIKit
#endif

enum SegmentCueNotificationScheduler {

    private static let identifierPrefix = "segmentCue-"
    private static let maxSets = 99
    private static let maxNumberedSetVoice = 20
    private static let workVoiceDirectory = "work_mp3"
    private static let restVoiceDirectory = "rest_mp3"

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
                content.title = "InterBeat"
                content.body = "Set \(setIndex) start"
                content.interruptionLevel = .timeSensitive
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
                    content.title = "InterBeat"
                    content.body = "Time to rest"
                    content.interruptionLevel = .timeSensitive
                    content.sound = restStartSound()
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                    let id = "\(identifierPrefix)rest-\(setIndex)"
                    requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
                boundaryElapsed += structure.restSeconds
            }
        }

        #if os(iOS)
        let app = UIApplication.shared
        var backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        backgroundTaskID = app.beginBackgroundTask(withName: "interfit.segmentCueSchedule") {
            if backgroundTaskID != .invalid {
                app.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        #endif

        let group = DispatchGroup()
        for request in requests {
            group.enter()
            center.add(request) { error in
                defer { group.leave() }
                guard let error else { return }
                #if DEBUG
                print("[SegmentCueNotificationScheduler] Failed to add \(request.identifier): \(error)")
                #endif
            }
        }

        group.notify(queue: .main) {
            #if os(iOS)
            if backgroundTaskID != .invalid {
                app.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
            #endif
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
        return sound(
            named: "set_\(setIndex)_start",
            fileExtension: "caf",
            preferredSubdirectory: workVoiceDirectory
        )
    }

    private static func restStartSound() -> UNNotificationSound {
        sound(
            named: "time_to_rest",
            fileExtension: "caf",
            preferredSubdirectory: restVoiceDirectory
        )
    }

    /// Resolve custom sound path from bundled resources.
    /// We prefer subdirectory paths because cue files are organized under work_mp3/rest_mp3.
    private static func sound(named baseName: String, fileExtension: String, preferredSubdirectory: String?) -> UNNotificationSound {
        if let preferredSubdirectory,
           Bundle.main.url(forResource: baseName, withExtension: fileExtension, subdirectory: preferredSubdirectory) != nil {
            return UNNotificationSound(named: UNNotificationSoundName("\(preferredSubdirectory)/\(baseName).\(fileExtension)"))
        }

        if Bundle.main.url(forResource: baseName, withExtension: fileExtension) != nil {
            return UNNotificationSound(named: UNNotificationSoundName("\(baseName).\(fileExtension)"))
        }
        return .default
    }
}
