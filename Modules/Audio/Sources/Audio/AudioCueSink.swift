import Foundation
import AVFoundation
#if canImport(AVFAudio)
import AVFAudio
#endif
import Shared

public enum AudioCuePattern: Equatable {
    case beepShort
    case beepTransition
    case beepSuccess
    case beepWarning
}

public final class AudioCueSink: @unchecked Sendable, CueSink {
    public struct Options: Sendable {
        public var duckOthers: Bool
        public var mixWithOthers: Bool
        public init(duckOthers: Bool = true, mixWithOthers: Bool = true) {
            self.duckOthers = duckOthers
            self.mixWithOthers = mixWithOthers
        }
    }

    public struct ToneConfig: Sendable {
        public var frequency: Double
        public var duration: TimeInterval
        public var gain: Float
    }

    public var isEnabled: Bool
    public var playHandler: (@Sendable ([AudioCuePattern]) -> Void)?
    public let options: Options
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private let amplitude: Float = 0.25

    public init(enabled: Bool = true, options: Options = Options(), playHandler: (@Sendable ([AudioCuePattern]) -> Void)? = nil) {
        self.isEnabled = enabled
        self.options = options
        self.playHandler = playHandler
        setupEngine()
    }

    public func emit(_ event: Shared.CueEventRecord) {
        guard isEnabled else { return }
        let patterns = AudioCueSink.map(event)
        if let handler = playHandler { handler(patterns) }
        else { play(patterns) }
    }

    public static func map(_ event: CueEventRecord) -> [AudioCuePattern] {
        guard let kind = event.kind else { return [] }
        switch kind {
        case .segmentStart:
            let segKind = event.attributes["kind"]
            if segKind == WorkoutSegmentKind.work.rawValue {
                return [.beepTransition]
            } else if segKind == WorkoutSegmentKind.rest.rawValue {
                return [.beepShort]
            } else {
                return [.beepShort]
            }
        case .workToRest:
            return [.beepWarning]
        case .restToWork:
            return [.beepSuccess]
        case .last3s:
            return [.beepShort]
        case .paused:
            return [.beepWarning]
        case .resumed:
            return [.beepShort]
        case .completed:
            return [.beepSuccess]
        }
    }
}

public extension AudioCueSink {
    static func config(for p: AudioCuePattern) -> ToneConfig {
        switch p {
        case .beepShort:
            return .init(frequency: 880, duration: 0.06, gain: 0.25)
        case .beepTransition:
            return .init(frequency: 660, duration: 0.09, gain: 0.25)
        case .beepSuccess:
            return .init(frequency: 1046, duration: 0.12, gain: 0.25)
        case .beepWarning:
            return .init(frequency: 523, duration: 0.12, gain: 0.25)
        }
    }
}

private extension AudioCueSink {
    func setupEngine() {
        #if os(iOS)
        do {
            var opts: AVAudioSession.CategoryOptions = []
            if options.duckOthers { opts.insert(.duckOthers) }
            if options.mixWithOthers { opts.insert(.mixWithOthers) }
            try AVAudioSession.sharedInstance().setCategory(.playback, options: opts)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silent failure in M0; future phases will log/degrade
        }
        #endif
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { }
    }

    func play(_ patterns: [AudioCuePattern]) {
        for p in patterns { playOne(p) }
    }

    func playOne(_ p: AudioCuePattern) {
        let cfg = Self.config(for: p)
        let buffer = makeSineBuffer(frequency: cfg.frequency, duration: cfg.duration, gain: cfg.gain)
        player.play()
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    func makeSineBuffer(frequency: Double, duration: TimeInterval, gain: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        let sampleRate = Float(format.sampleRate)
        let freq = Float(frequency)
        for i in 0..<Int(frameCount) {
            samples[i] = sinf(2 * .pi * freq * Float(i) / sampleRate) * gain // low volume
        }
        return buffer
    }
}
