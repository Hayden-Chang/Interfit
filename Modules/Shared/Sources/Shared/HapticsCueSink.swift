import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Cross-platform logical haptic patterns for testability
public enum HapticPattern: Equatable {
    case impactLight
    case impactMedium
    case impactHeavy
    case impactSoft
    case impactRigid
    case notificationSuccess
    case notificationWarning
    case notificationError
}

public struct HapticsCueSink: CueSink {
    public var isEnabled: Bool
    // Optional test hook to observe played patterns
    public var playHandler: (@Sendable ([HapticPattern]) -> Void)?

    public init(enabled: Bool = true, playHandler: (@Sendable ([HapticPattern]) -> Void)? = nil) {
        self.isEnabled = enabled
        self.playHandler = playHandler
    }

    public func emit(_ event: CueEventRecord) {
        guard isEnabled else { return }
        let patterns = HapticsCueSink.map(event)
        if let handler = playHandler {
            handler(patterns)
        } else {
            play(patterns)
        }
    }

    // Pure mapping used by tests
    public static func map(_ event: CueEventRecord) -> [HapticPattern] {
        guard let kind = event.kind else { return [] }
        switch kind {
        case .segmentStart:
            // If entering work: more assertive; rest: softer
            let segKind = event.attributes["kind"]
            if segKind == WorkoutSegmentKind.work.rawValue {
                return [.impactRigid]
            } else if segKind == WorkoutSegmentKind.rest.rawValue {
                return [.impactSoft]
            } else {
                return [.impactMedium]
            }
        case .workToRest:
            return [.notificationWarning]
        case .restToWork:
            return [.notificationSuccess]
        case .last3s:
            return [.impactLight]
        case .paused:
            return [.notificationWarning]
        case .resumed:
            return [.impactLight]
        case .completed:
            return [.notificationSuccess]
        }
    }
}

private extension HapticsCueSink {
    func play(_ patterns: [HapticPattern]) {
        #if os(iOS)
        for p in patterns { playOne(p) }
        #else
        // Non-iOS platforms: no-op (silent when unsupported)
        _ = patterns // keep "used"
        #endif
    }

    #if os(iOS)
    func playOne(_ p: HapticPattern) {
        switch p {
        case .notificationSuccess:
            let gen = UINotificationFeedbackGenerator(); gen.prepare(); gen.notificationOccurred(.success)
        case .notificationWarning:
            let gen = UINotificationFeedbackGenerator(); gen.prepare(); gen.notificationOccurred(.warning)
        case .notificationError:
            let gen = UINotificationFeedbackGenerator(); gen.prepare(); gen.notificationOccurred(.error)
        case .impactLight:
            let gen = UIImpactFeedbackGenerator(style: .light); gen.prepare(); gen.impactOccurred()
        case .impactMedium:
            let gen = UIImpactFeedbackGenerator(style: .medium); gen.prepare(); gen.impactOccurred()
        case .impactHeavy:
            let gen = UIImpactFeedbackGenerator(style: .heavy); gen.prepare(); gen.impactOccurred()
        case .impactSoft:
            if #available(iOS 13.0, *) {
                let gen = UIImpactFeedbackGenerator(style: .soft); gen.prepare(); gen.impactOccurred()
            } else {
                let gen = UIImpactFeedbackGenerator(style: .light); gen.prepare(); gen.impactOccurred()
            }
        case .impactRigid:
            if #available(iOS 13.0, *) {
                let gen = UIImpactFeedbackGenerator(style: .rigid); gen.prepare(); gen.impactOccurred()
            } else {
                let gen = UIImpactFeedbackGenerator(style: .heavy); gen.prepare(); gen.impactOccurred()
            }
        }
    }
    #endif
}
