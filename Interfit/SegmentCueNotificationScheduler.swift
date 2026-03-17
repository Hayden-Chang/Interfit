import Foundation
import UserNotifications
import Shared
#if os(iOS)
import UIKit
#endif

protocol SegmentCueNotificationCentering: AnyObject {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func getPendingNotificationRequestIdentifiers(_ completion: @escaping ([String]) -> Void)
    func getDeliveredNotificationIdentifiers(_ completion: @escaping ([String]) -> Void)
}

final class LiveSegmentCueNotificationCenter: SegmentCueNotificationCentering {
    static let shared = LiveSegmentCueNotificationCenter()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        center.add(request, withCompletionHandler: completionHandler)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func getPendingNotificationRequestIdentifiers(_ completion: @escaping ([String]) -> Void) {
        center.getPendingNotificationRequests { requests in
            completion(requests.map(\.identifier))
        }
    }

    func getDeliveredNotificationIdentifiers(_ completion: @escaping ([String]) -> Void) {
        center.getDeliveredNotifications { notifications in
            completion(notifications.map { $0.request.identifier })
        }
    }
}

protocol SegmentCueDispatching {
    func asyncAfter(seconds: TimeInterval, execute: @escaping () -> Void)
}

struct MainSegmentCueDispatcher: SegmentCueDispatching {
    static let shared = MainSegmentCueDispatcher()

    func asyncAfter(seconds: TimeInterval, execute: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            execute()
        }
    }
}

enum SegmentCueNotificationScheduler {

    private static let identifierPrefix = "segmentCue-"
    private static let maxSets = 99
    private static let maxNumberedSetVoice = 20
    private static let workVoiceDirectory = "work_mp3"
    private static let restVoiceDirectory = "rest_mp3"
    private static let cleanupSweepDelays: [TimeInterval] = [0.2, 1.0, 2.5]
    private static let generationQueue = DispatchQueue(label: "interfit.segmentCue.generation")
    private static var cleanupGeneration: UInt64 = 0

    /// Schedule notifications for all future segment boundaries.
    /// - Parameters:
    ///   - structure: the workout's WorkoutStructure
    ///   - currentElapsed: engine's current elapsed seconds
    static func schedule(
        structure: WorkoutStructure,
        currentElapsed: Int,
        center: SegmentCueNotificationCentering = LiveSegmentCueNotificationCenter.shared
    ) {
        let generation = bumpGeneration()
        clearSegmentNotifications(using: center)

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

            // Rest segment start
            if structure.restSeconds > 0 {
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
            guard isGenerationCurrent(generation) else { break }
            group.enter()
            center.add(request, withCompletionHandler: { error in
                defer { group.leave() }
                guard let error else { return }
                #if DEBUG
                print("[SegmentCueNotificationScheduler] Failed to add \(request.identifier): \(error)")
                #endif
            })
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

    static func cancelAll(
        center: SegmentCueNotificationCentering = LiveSegmentCueNotificationCenter.shared,
        dispatcher: SegmentCueDispatching = MainSegmentCueDispatcher.shared
    ) {
        let generation = bumpGeneration()
        clearSegmentNotifications(using: center)

        // Handle add/remove race with notification daemon: do delayed sweeps after initial cancel.
        for delay in cleanupSweepDelays {
            dispatcher.asyncAfter(seconds: delay) {
                guard isGenerationCurrent(generation) else { return }
                clearSegmentNotifications(using: center)
            }
        }
    }

    private static func bumpGeneration() -> UInt64 {
        generationQueue.sync {
            cleanupGeneration &+= 1
            return cleanupGeneration
        }
    }

    private static func isGenerationCurrent(_ generation: UInt64) -> Bool {
        generationQueue.sync { cleanupGeneration == generation }
    }

    private static func clearSegmentNotifications(using center: SegmentCueNotificationCentering) {
        let knownIdentifiers = allPossibleIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: knownIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: knownIdentifiers)

        center.getPendingNotificationRequestIdentifiers { ids in
            let stale = ids.filter { $0.hasPrefix(identifierPrefix) }
            guard !stale.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        center.getDeliveredNotificationIdentifiers { ids in
            let stale = ids.filter { $0.hasPrefix(identifierPrefix) }
            guard !stale.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: stale)
        }
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
