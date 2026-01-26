import Foundation

public protocol CueSink: Sendable {
    func emit(_ event: CueEventRecord)
}

public struct NoopCueSink: CueSink {
    public init() {}
    public func emit(_ event: CueEventRecord) { /* no-op */ }
}
