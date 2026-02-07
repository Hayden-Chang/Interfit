import Foundation
import AVFoundation
import Shared

public final class SpeechCueSink: @unchecked Sendable, CueSink {
    public var isEnabled: Bool
    private let synthesizer = AVSpeechSynthesizer()
    private let voiceIdentifier: String?

    public init(enabled: Bool = true, voiceIdentifier: String? = nil) {
        self.isEnabled = enabled
        self.voiceIdentifier = voiceIdentifier
    }

    public func emit(_ event: Shared.CueEventRecord) {
        guard isEnabled else { return }
        guard let kind = event.kind else { return }

        let phrase: String?
        switch kind {
        case .segmentStart:
            let segKind = event.attributes["kind"]
            if segKind == WorkoutSegmentKind.work.rawValue {
                phrase = "Work"
            } else if segKind == WorkoutSegmentKind.rest.rawValue {
                phrase = "Rest"
            } else {
                phrase = nil
            }
        case .last3s:
            let remaining = Int(event.attributes["remaining"] ?? "")
            switch remaining {
            case 3:
                phrase = "3"
            case 2:
                phrase = "2"
            case 1:
                phrase = "1"
            default:
                phrase = "3"
            }
        case .paused:
            phrase = "Paused"
        case .resumed:
            phrase = "Resume"
        case .completed:
            phrase = "Done"
        case .workToRest, .restToWork:
            phrase = nil
        }

        guard let phrase else { return }
        Task { @MainActor in
            let utterance = AVSpeechUtterance(string: phrase)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                utterance.voice = voice
            }
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.speak(utterance)
        }
    }
}
