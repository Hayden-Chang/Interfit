import Foundation

public enum WorkoutPreflightStatus: String, Sendable, Codable, Equatable {
    case ok
    case timeout
    case failed
}

/// Minimal "start workout" preflight result (3.3.1).
public struct WorkoutPreflightReport: Sendable, Codable, Equatable {
    public var name: String
    public var status: WorkoutPreflightStatus
    public var durationMs: Int
    public var attributes: [String: String]

    public init(
        name: String,
        status: WorkoutPreflightStatus,
        durationMs: Int,
        attributes: [String: String] = [:]
    ) {
        self.name = name
        self.status = status
        self.durationMs = max(0, durationMs)
        self.attributes = attributes
    }

    public func asSessionEventRecord(occurredAt: Date = Date()) -> SessionEventRecord {
        var attrs = attributes
        attrs["name"] = name
        attrs["status"] = status.rawValue
        attrs["durationMs"] = "\(durationMs)"
        return .init(name: "preflight", occurredAt: occurredAt, attributes: attrs)
    }
}

public enum WorkoutPreflightRunner {
    /// Runs a preflight operation with a timeout. Timeout is reported as `.timeout` and never throws.
    public static func run(
        name: String,
        timeoutSeconds: Double,
        operation: @escaping @Sendable () async throws -> [String: String]
    ) async -> WorkoutPreflightReport {
        let startedAt = Date()

        return await withTaskGroup(of: WorkoutPreflightReport.self) { group in
            group.addTask {
                do {
                    let attributes = try await operation()
                    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                    return WorkoutPreflightReport(name: name, status: .ok, durationMs: durationMs, attributes: attributes)
                } catch {
                    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                    return WorkoutPreflightReport(
                        name: name,
                        status: .failed,
                        durationMs: durationMs,
                        attributes: ["error": String(describing: error)]
                    )
                }
            }

            group.addTask {
                let nanos = UInt64(max(0, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                return WorkoutPreflightReport(name: name, status: .timeout, durationMs: durationMs)
            }

            let first = (await group.next()) ?? WorkoutPreflightReport(name: name, status: .failed, durationMs: 0)
            group.cancelAll()
            return first
        }
    }
}

