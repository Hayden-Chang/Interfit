import Foundation
import MediaPlayer
import Persistence
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTerminationMarker {
    private static let terminationRequestedKey = "interfit.lifecycle.terminationRequested"

    static func markTerminationRequested() {
        UserDefaults.standard.set(true, forKey: terminationRequestedKey)
    }

    static func consumeTerminationRequested() -> Bool {
        let defaults = UserDefaults.standard
        let value = defaults.bool(forKey: terminationRequestedKey)
        if value {
            defaults.removeObject(forKey: terminationRequestedKey)
        }
        return value
    }
}

@MainActor
enum AppTerminationCoordinator {
    static func handleWillTerminate() {
        AppTerminationMarker.markTerminationRequested()
        SegmentCueNotificationScheduler.cancelAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MusicPlaybackClient.pauseIfOwnedByInterfitForAppTermination()
        Task {
            let store = CoreDataPersistenceStore()
            await store.clearRecoverableSessionSnapshot()
        }
    }

    static func handleRelaunchAfterTermination() async {
        guard AppTerminationMarker.consumeTerminationRequested() else { return }
        SegmentCueNotificationScheduler.cancelAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MusicPlaybackClient.pauseIfOwnedByInterfitForAppTermination()
        let store = CoreDataPersistenceStore()
        await store.clearRecoverableSessionSnapshot()
    }
}

#if canImport(UIKit)
final class InterfitAppDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        _ = application
        Task { @MainActor in
            AppTerminationCoordinator.handleWillTerminate()
        }
    }
}
#endif
