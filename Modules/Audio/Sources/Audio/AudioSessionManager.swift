import Foundation
import AVFoundation
#if canImport(AVFAudio)
import AVFAudio
#endif

public struct AudioSessionRequest: Sendable, Equatable {
    public var duckOthers: Bool
    public var mixWithOthers: Bool

    public init(duckOthers: Bool, mixWithOthers: Bool) {
        self.duckOthers = duckOthers
        self.mixWithOthers = mixWithOthers
    }

    public static let none = AudioSessionRequest(duckOthers: false, mixWithOthers: false)

    func merged(with other: AudioSessionRequest) -> AudioSessionRequest {
        AudioSessionRequest(
            duckOthers: duckOthers || other.duckOthers,
            mixWithOthers: mixWithOthers || other.mixWithOthers
        )
    }
}

public enum AudioRouteChangeReason: String, Sendable, Equatable {
    case unknown
    case newDeviceAvailable
    case oldDeviceUnavailable
    case categoryChange
    case override
    case wakeFromSleep
    case noSuitableRouteForCategory
    case routeConfigurationChange
}

public enum AudioSessionEvent: Sendable, Equatable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case routeChanged(reason: AudioRouteChangeReason)
}

public final class AudioSessionObservationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false
    private let cancelImpl: () -> Void

    public init(cancel: @escaping () -> Void) {
        self.cancelImpl = cancel
    }

    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard !isCancelled else { return }
        isCancelled = true
        cancelImpl()
    }

    deinit { cancel() }
}

/// AudioSession management facade (2.2.2).
///
/// - Note: iOS uses `AVAudioSession`; other platforms no-op.
public final class AudioSessionManager: @unchecked Sendable {
    public static let shared = AudioSessionManager()

    private let notificationCenter: NotificationCenter
    private let applyRequest: @Sendable (AudioSessionRequest) -> Void

    private let stateLock = NSLock()
    private var activeRequests: [UUID: AudioSessionRequest] = [:]
    private var appliedRequest: AudioSessionRequest?
    private var legacyCuesToken: AudioSessionObservationToken?

    public init(
        notificationCenter: NotificationCenter = .default,
        applyRequest: @escaping @Sendable (AudioSessionRequest) -> Void = { AudioSessionManager.defaultApplyRequest($0) }
    ) {
        self.notificationCenter = notificationCenter
        self.applyRequest = applyRequest
    }

    /// Begins a "cues" request for the session and returns a token that releases the request on cancel/deinit.
    ///
    /// Minimal coexistence strategy (2.2.2):
    /// - Multiple callers can hold requests concurrently (e.g. training playback + cues).
    /// - Options are merged as a union (duck/mix OR).
    public func beginCues(options: AudioCueSink.Options) -> AudioSessionObservationToken {
        begin(request: AudioSessionRequest(duckOthers: options.duckOthers, mixWithOthers: options.mixWithOthers))
    }

    /// Begins a "playback" request for the session and returns a token that releases the request on cancel/deinit.
    public func beginPlayback(mixWithOthers: Bool = true) -> AudioSessionObservationToken {
        begin(request: AudioSessionRequest(duckOthers: false, mixWithOthers: mixWithOthers))
    }

    /// Backward-compatible entrypoint for older call sites that didn't retain a token.
    @available(*, deprecated, message: "Use beginCues(options:) and hold the returned token for the lifetime of the cue sink.")
    public func activateForCues(options: AudioCueSink.Options) {
        legacyCuesToken = beginCues(options: options)
    }

    public func begin(request: AudioSessionRequest) -> AudioSessionObservationToken {
        let id = UUID()
        var requestToApply: AudioSessionRequest?
        stateLock.lock()
        activeRequests[id] = request
        requestToApply = mergedRequestToApplyLocked()
        stateLock.unlock()
        if let requestToApply { applyRequest(requestToApply) }

        return AudioSessionObservationToken(cancel: { [weak self] in
            guard let self else { return }
            var requestToApply: AudioSessionRequest?
            self.stateLock.lock()
            self.activeRequests.removeValue(forKey: id)
            if self.activeRequests.isEmpty {
                self.appliedRequest = nil
            } else {
                requestToApply = self.mergedRequestToApplyLocked()
            }
            self.stateLock.unlock()
            if let requestToApply { self.applyRequest(requestToApply) }
        })
    }

    public func startObserving(_ handler: @escaping @Sendable (AudioSessionEvent) -> Void) -> AudioSessionObservationToken {
        #if os(iOS)
        var observers: [NSObjectProtocol] = []

        let interruption = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { note in
            guard let userInfo = note.userInfo else { return }
            let typeValue = (userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
            guard let typeValue else { return }
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            switch type {
            case .began:
                handler(.interruptionBegan)
            case .ended:
                let optionsValue = (userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
                handler(.interruptionEnded(shouldResume: shouldResume))
            case .none:
                break
            @unknown default:
                break
            }
        }
        observers.append(interruption)

        let routeChange = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { note in
            let userInfo = note.userInfo
            let reasonValue = (userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            let reason = AudioRouteChangeReason(avRouteRawValue: reasonValue)
            handler(.routeChanged(reason: reason))
        }
        observers.append(routeChange)

        return AudioSessionObservationToken(cancel: { [notificationCenter] in
            for obs in observers { notificationCenter.removeObserver(obs) }
        })
        #else
        return AudioSessionObservationToken(cancel: {})
        #endif
    }

    private func mergedRequestToApplyLocked() -> AudioSessionRequest? {
        guard !activeRequests.isEmpty else { return nil }
        let combined = activeRequests.values.reduce(AudioSessionRequest.none) { $0.merged(with: $1) }
        guard combined != appliedRequest else { return nil }
        appliedRequest = combined
        return combined
    }

    public static func defaultApplyRequest(_ request: AudioSessionRequest) {
        #if os(iOS)
        do {
            var opts: AVAudioSession.CategoryOptions = []
            if request.duckOthers { opts.insert(.duckOthers) }
            if request.mixWithOthers { opts.insert(.mixWithOthers) }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: opts)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 2.2.2: best-effort. Higher layers will surface degrade reasons later.
        }
        #else
        _ = request
        #endif
    }
}

private extension AudioRouteChangeReason {
    init(avRouteRawValue: UInt?) {
        #if os(iOS)
        guard let raw = avRouteRawValue else { self = .unknown; return }
        switch AVAudioSession.RouteChangeReason(rawValue: raw) {
        case .newDeviceAvailable: self = .newDeviceAvailable
        case .oldDeviceUnavailable: self = .oldDeviceUnavailable
        case .categoryChange: self = .categoryChange
        case .override: self = .override
        case .wakeFromSleep: self = .wakeFromSleep
        case .noSuitableRouteForCategory: self = .noSuitableRouteForCategory
        case .routeConfigurationChange: self = .routeConfigurationChange
        case .unknown, .none: self = .unknown
        @unknown default: self = .unknown
        }
        #else
        self = .unknown
        #endif
    }
}
