import Foundation
import AVFoundation
import Audio

/// Keeps the app eligible for background execution by playing a silent loop.
/// This allows workout ticks/cues to continue when the app is not active.
@MainActor
final class BackgroundAudioKeepAlive {
    static let shared = BackgroundAudioKeepAlive()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let loopDurationSeconds: TimeInterval = 2

    private var isConfigured = false
    private var isRunning = false
    private var sessionToken: AudioSessionObservationToken?

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    }

    func start() {
        guard !isRunning else { return }

        configureIfNeeded()
        sessionToken = AudioSessionManager.shared.beginPlayback(mixWithOthers: true)

        do {
            if !engine.isRunning {
                try engine.start()
            }
            isRunning = true
            scheduleNextBuffer()
            if !player.isPlaying {
                player.play()
            }
        } catch {
            isRunning = false
            sessionToken?.cancel()
            sessionToken = nil
        }
    }

    func stop() {
        guard isRunning || sessionToken != nil else { return }

        isRunning = false
        player.stop()
        player.reset()
        engine.stop()
        sessionToken?.cancel()
        sessionToken = nil
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isConfigured = true
    }

    private func scheduleNextBuffer() {
        guard isRunning else { return }
        let buffer = makeSilentBuffer(durationSeconds: loopDurationSeconds)
        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.scheduleNextBuffer()
            }
        }
    }

    private func makeSilentBuffer(durationSeconds: TimeInterval) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(durationSeconds * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let channel = buffer.floatChannelData?[0] {
            for i in 0 ..< Int(frameCount) {
                channel[i] = 0
            }
        }
        return buffer
    }
}
