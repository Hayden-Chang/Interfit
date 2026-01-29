import XCTest
@testable import Shared

final class WorkoutPreflightRunnerTests: XCTestCase {
    func test_run_ok_returnsAttributes() async {
        let report = await WorkoutPreflightRunner.run(name: "startWorkout", timeoutSeconds: 1.0) {
            ["k": "v"]
        }

        XCTAssertEqual(report.name, "startWorkout")
        XCTAssertEqual(report.status, .ok)
        XCTAssertGreaterThanOrEqual(report.durationMs, 0)
        XCTAssertEqual(report.attributes, ["k": "v"])
    }

    func test_run_failed_capturesError() async {
        struct TestError: Error {}

        let report = await WorkoutPreflightRunner.run(name: "startWorkout", timeoutSeconds: 1.0) {
            throw TestError()
        }

        XCTAssertEqual(report.name, "startWorkout")
        XCTAssertEqual(report.status, .failed)
        XCTAssertGreaterThanOrEqual(report.durationMs, 0)
        XCTAssertNotNil(report.attributes["error"])
    }

    func test_run_timeout_returnsTimeout() async {
        let report = await WorkoutPreflightRunner.run(name: "startWorkout", timeoutSeconds: 0.05) {
            try await Task.sleep(nanoseconds: 300_000_000)
            return ["k": "v"]
        }

        XCTAssertEqual(report.name, "startWorkout")
        XCTAssertEqual(report.status, .timeout)
        XCTAssertGreaterThanOrEqual(report.durationMs, 0)
    }
}

