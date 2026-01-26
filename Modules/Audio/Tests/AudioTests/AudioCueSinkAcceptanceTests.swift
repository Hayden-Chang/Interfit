import XCTest
@testable import Audio

final class AudioCueSinkAcceptanceTests: XCTestCase {
    func test_default_options_enable_coexistence_flags() {
        let sink = AudioCueSink()
        XCTAssertTrue(sink.options.duckOthers)
        XCTAssertTrue(sink.options.mixWithOthers)
    }

    func test_beep_envelope_not_harsh() {
        // Durations should be short; gain should remain low.
        let patterns: [AudioCuePattern] = [.beepShort, .beepTransition, .beepSuccess, .beepWarning]
        for p in patterns {
            let cfg = AudioCueSink.config(for: p)
            XCTAssertLessThanOrEqual(cfg.duration, 0.15, "duration too long for pattern: \(p)")
            XCTAssertLessThanOrEqual(cfg.gain, 0.3, "gain too high for pattern: \(p)")
            XCTAssertGreaterThan(cfg.frequency, 300, "frequency too low (muddy): \(p)")
            XCTAssertLessThan(cfg.frequency, 2000, "frequency too high (shrill): \(p)")
        }
    }
}
