import Foundation

public enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error
}

public struct LogEntry: Sendable, Equatable {
    public let level: LogLevel
    public let name: String
    public let attributes: [String: String]

    public init(level: LogLevel, name: String, attributes: [String: String] = [:]) {
        self.level = level
        self.name = name
        self.attributes = attributes
    }
}

public protocol Logger: Sendable {
    func log(_ entry: LogEntry)
}

public struct NoopLogger: Logger {
    public init() {}
    public func log(_ entry: LogEntry) {}
}

public extension Logger {
    func debug(_ name: String, _ attributes: [String: String] = [:]) {
        log(.init(level: .debug, name: name, attributes: attributes))
    }

    func info(_ name: String, _ attributes: [String: String] = [:]) {
        log(.init(level: .info, name: name, attributes: attributes))
    }

    func warning(_ name: String, _ attributes: [String: String] = [:]) {
        log(.init(level: .warning, name: name, attributes: attributes))
    }

    func error(_ name: String, _ attributes: [String: String] = [:]) {
        log(.init(level: .error, name: name, attributes: attributes))
    }
}

