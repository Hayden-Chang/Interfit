import Foundation
import MediaPlayer
import Shared
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class NowPlayingManager: ObservableObject {
    static let remotePlayNotification = Notification.Name("interfit.remote.play")
    static let remotePauseNotification = Notification.Name("interfit.remote.pause")
    static let remoteToggleNotification = Notification.Name("interfit.remote.togglePlayPause")

    private let notificationCenter: NotificationCenter
    private var isStarted: Bool = false

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        #if canImport(UIKit)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif

        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true

        commands.playCommand.addTarget { [notificationCenter] _ in
            notificationCenter.post(name: Self.remotePlayNotification, object: nil)
            return .success
        }
        commands.pauseCommand.addTarget { [notificationCenter] _ in
            notificationCenter.post(name: Self.remotePauseNotification, object: nil)
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [notificationCenter] _ in
            notificationCenter.post(name: Self.remoteToggleNotification, object: nil)
            return .success
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.removeTarget(nil)
        commands.pauseCommand.removeTarget(nil)
        commands.togglePlayPauseCommand.removeTarget(nil)
        commands.playCommand.isEnabled = false
        commands.pauseCommand.isEnabled = false
        commands.togglePlayPauseCommand.isEnabled = false

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        #if canImport(UIKit)
        UIApplication.shared.endReceivingRemoteControlEvents()
        #endif
    }

    func update(planName: String?, progress: WorkoutProgress?, sessionStatus: SessionStatus) {
        guard isStarted else { return }

        guard let progress, let seg = progress.currentSegment, !progress.isCompleted else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyTitle: planName ?? "Interfit",
                MPMediaItemPropertyArtist: sessionStatus == .ended ? "Ended" : "Completed",
                MPNowPlayingInfoPropertyPlaybackRate: 0.0,
            ]
            return
        }

        let segmentTitle: String = switch seg.kind {
        case .work: "Work"
        case .rest: "Rest"
        }

        let subtitle = "\(segmentTitle) • \(seg.setIndex)/\(max(1, progress.totalSets))"
        let rate: Double = (sessionStatus == .running) ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: planName ?? "Interfit",
            MPMediaItemPropertyArtist: subtitle,
            MPMediaItemPropertyPlaybackDuration: Double(seg.durationSeconds),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(progress.currentSegmentElapsedSeconds),
            MPNowPlayingInfoPropertyPlaybackRate: rate,
        ]
    }
}
