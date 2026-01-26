import XCTest
@testable import Shared

final class SessionStateMachineTests: XCTestCase {
    func test_allowedTransitions() throws {
        var sm = SessionStateMachine()
        XCTAssertEqual(sm.status, .idle)

        try sm.start()
        XCTAssertEqual(sm.status, .running)

        try sm.pause(reason: .user)
        XCTAssertEqual(sm.status, .paused)

        try sm.resume()
        XCTAssertEqual(sm.status, .running)

        try sm.complete()
        XCTAssertEqual(sm.status, .completed)
    }

    func test_invalidTransitions_throw() {
        var sm = SessionStateMachine(status: .idle)
        XCTAssertThrowsError(try sm.pause(reason: .user)) { err in
            XCTAssertEqual(err as? SessionTransitionError, .invalidTransition(from: .idle, to: .paused))
        }
    }

    func test_endFromPaused_isAllowed() throws {
        var sm = SessionStateMachine(status: .running)
        try sm.pause(reason: .safety)
        try sm.end()
        XCTAssertEqual(sm.status, .ended)
    }
}

