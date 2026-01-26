import XCTest
@testable import Shared

final class LoggerTests: XCTestCase {
    func test_noopLogger_acceptsEntries() {
        let logger: any Logger = NoopLogger()
        logger.info("app.launch", ["mode": "test"])
        logger.error("test.error", ["reason": "unit"])
        XCTAssertTrue(true) // smoke test: should not crash
    }
}

