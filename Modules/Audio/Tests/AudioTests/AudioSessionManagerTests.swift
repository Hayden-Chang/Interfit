import XCTest
@testable import Audio

final class AudioSessionManagerTests: XCTestCase {
    func test_observationToken_cancel_isIdempotent_andDeinitDoesNotDoubleCancel() {
        let lock = NSLock()
        var cancelCount = 0

        var token: AudioSessionObservationToken? = AudioSessionObservationToken(cancel: {
            lock.lock()
            defer { lock.unlock() }
            cancelCount += 1
        })

        token?.cancel()
        token?.cancel()
        token = nil

        XCTAssertEqual(cancelCount, 1)
    }

    func test_beginPlayback_then_beginCues_mergesOptions_and_revertsWhenCuesEnd() {
        let applied = Locked<[AudioSessionRequest]>([])
        let manager = AudioSessionManager(
            notificationCenter: .init(),
            applyRequest: { request in
                applied.withLock { $0.append(request) }
            }
        )

        let playback = manager.beginPlayback(mixWithOthers: true)
        let cues = manager.beginCues(options: .init(duckOthers: true, mixWithOthers: true))

        cues.cancel()
        playback.cancel()

        let snapshot = applied.value

        XCTAssertEqual(snapshot, [
            .init(duckOthers: false, mixWithOthers: true),
            .init(duckOthers: true, mixWithOthers: true),
            .init(duckOthers: false, mixWithOthers: true),
        ])
    }

    func test_beginPlayback_doesNotDeadlock_whenApplyRequestReentersManager() {
        let applied = Locked<[AudioSessionRequest]>([])
        let didReenter = Locked(false)

        let managerBox = Locked<AudioSessionManager?>(nil)
        let manager = AudioSessionManager(
            notificationCenter: .init(),
            applyRequest: { request in
                applied.withLock { $0.append(request) }

                let shouldReenter = didReenter.withLock { value in
                    if value { return false }
                    value = true
                    return true
                }
                guard shouldReenter else { return }

                guard let manager = managerBox.value else { return }
                let token = manager.beginPlayback(mixWithOthers: true)
                token.cancel()
            }
        )
        managerBox.withLock { $0 = manager }

        let exp = expectation(description: "beginPlayback completes")
        DispatchQueue.global().async {
            let token = manager.beginPlayback(mixWithOthers: true)
            token.cancel()
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertFalse(applied.value.isEmpty)
    }

    func test_audioCueSink_claimsSessionOnInit_andReclaimsOnReenable() {
        let applied = Locked<[AudioSessionRequest]>([])
        let manager = AudioSessionManager(
            notificationCenter: .init(),
            applyRequest: { request in
                applied.withLock { $0.append(request) }
            }
        )

        let sink = AudioCueSink(enabled: true, sessionManager: manager) { _ in }
        sink.isEnabled = false
        sink.isEnabled = true

        let snapshot = applied.value

        XCTAssertGreaterThanOrEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.first, .init(duckOthers: true, mixWithOthers: true))
        XCTAssertEqual(snapshot.last, .init(duckOthers: true, mixWithOthers: true))
    }
}
