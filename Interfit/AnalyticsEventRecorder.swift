import Foundation

struct AnalyticsEvent: Codable, Sendable, Equatable {
    var name: String
    var createdAt: Date
    var properties: [String: String]
}

actor AnalyticsEventRecorder {
    static let shared = AnalyticsEventRecorder()

    static let optInKey = "interfit.analytics.optIn"
    static let fileName = "analytics_events.jsonl"

    /// A strict allowlist to prevent accidental collection of content-like fields
    /// (e.g. song title, artist name, comment text).
    static let allowedPropertyKeys: Set<String> = [
        "entry",
        "reason",
        "kind",
        "result",
        "source",
        "action",
        "usable",
        "decision",
        "post_type",
    ]

    func recordAppOpen() async {
        await record(name: "app.open", properties: [:])
    }

    func record(name: String, properties: [String: String]) async {
        guard Self.isOptedIn else { return }

        let sanitized = properties.filter { Self.allowedPropertyKeys.contains($0.key) }
        let event = AnalyticsEvent(name: name, createdAt: Date(), properties: sanitized)

        do {
            let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(Self.fileName)

            let data = try JSONEncoder.iso8601.encode(event)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.write(contentsOf: Data("\n".utf8))
                try handle.close()
            } else {
                var newData = Data()
                newData.append(data)
                newData.append(Data("\n".utf8))
                try newData.write(to: url, options: [.atomic])
            }
        } catch {
            // Best-effort: analytics should never crash the app.
            NSLog("[Analytics] Failed to record event: %@", String(describing: error))
        }
    }

    private static var isOptedIn: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: optInKey) == nil { return true }
        return defaults.bool(forKey: optInKey)
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}

