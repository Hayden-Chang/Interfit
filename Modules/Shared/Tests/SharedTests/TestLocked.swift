import Foundation

/// Tiny test-only lock wrapper to satisfy Swift 6 Sendable checks when closures are `@Sendable`.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&_value)
    }

    var value: Value {
        withLock { $0 }
    }
}
