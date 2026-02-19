import Foundation
import AVFoundation
import Shared
#if os(iOS)
import UIKit
#endif

public final class SpeechCueSink: @unchecked Sendable, CueSink {
    enum CueAction: Equatable {
        case playMP3(name: String, subdirectory: String)
        case speak(String)
        case none
    }

    public var isEnabled: Bool
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let voiceIdentifier: String?
    private let isForeground: () -> Bool

    public init(
        enabled: Bool = true,
        voiceIdentifier: String? = nil,
        isForeground: (() -> Bool)? = nil
    ) {
        self.isEnabled = enabled
        self.voiceIdentifier = voiceIdentifier
        self.isForeground = isForeground ?? Self.defaultForegroundCheck
    }

    public func emit(_ event: Shared.CueEventRecord) {
        guard isEnabled else { return }
        switch Self.resolveAction(for: event, isForeground: isForeground()) {
        case let .playMP3(name, subdirectory):
            playMP3(name: name, subdirectory: subdirectory)
        case let .speak(phrase):
            speak(phrase)
        case .none:
            break
        }
    }

    static func resolveAction(for event: Shared.CueEventRecord, isForeground: Bool) -> CueAction {
        guard let kind = event.kind else { return .none }

        switch kind {
        case .segmentStart:
            guard isForeground else { return .none }
            let segKind = event.attributes["kind"]
            if segKind == WorkoutSegmentKind.work.rawValue {
                let setIndex = event.attributes["set"] ?? "1"
                return .playMP3(name: "set_\(setIndex)_start", subdirectory: "work_mp3")
            } else if segKind == WorkoutSegmentKind.rest.rawValue {
                return .playMP3(name: "time_to_rest", subdirectory: "rest_mp3")
            } else {
                return .none
            }
        case .completed:
            return .speak("Done")
        case .last3s, .paused, .resumed, .workToRest, .restToWork:
            return .none
        }
    }

    private static func defaultForegroundCheck() -> Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        true
        #endif
    }

    private func playMP3(name: String, subdirectory: String) {
        let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: subdirectory)
                  ?? Bundle.main.url(forResource: name, withExtension: "mp3")
        guard let url else {
            print("[SpeechCueSink] MP3 not found: \(name) (subdirectory: \(subdirectory))")
            return
        }
        Task { @MainActor in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                self.audioPlayer = player
                player.play()
            } catch {
                print("[SpeechCueSink] AVAudioPlayer error: \(error)")
            }
        }
    }

    private func speak(_ phrase: String) {
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
