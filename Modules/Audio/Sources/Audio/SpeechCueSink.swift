import Foundation
import AVFoundation
import Shared

public final class SpeechCueSink: @unchecked Sendable, CueSink {
    public var isEnabled: Bool
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let voiceIdentifier: String?

    public init(enabled: Bool = true, voiceIdentifier: String? = nil) {
        self.isEnabled = enabled
        self.voiceIdentifier = voiceIdentifier
    }

    public func emit(_ event: Shared.CueEventRecord) {
        guard isEnabled else { return }
        guard let kind = event.kind else { return }

        switch kind {
        case .segmentStart:
            let segKind = event.attributes["kind"]
            if segKind == WorkoutSegmentKind.work.rawValue {
                let setIndex = event.attributes["set"] ?? "1"
                playMP3(name: "set_\(setIndex)_start", subdirectory: "work_mp3")
            } else if segKind == WorkoutSegmentKind.rest.rawValue {
                playMP3(name: "time_to_rest", subdirectory: "rest_mp3")
            }
        case .completed:
            speak("Done")
        case .last3s, .paused, .resumed, .workToRest, .restToWork:
            break
        }
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
