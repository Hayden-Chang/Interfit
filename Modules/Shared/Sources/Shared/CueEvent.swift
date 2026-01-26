import Foundation

public enum CueEventKind: String, Sendable, Codable, CaseIterable {
    case segmentStart
    case workToRest
    case restToWork
    case last3s
    case paused
    case resumed
    case completed
}

public struct CueEventRecord: Sendable, Codable, Equatable {
    public var name: String
    public var occurredAt: Date
    public var attributes: [String: String]

    public init(name: String, occurredAt: Date = Date(), attributes: [String: String] = [:]) {
        self.name = name
        self.occurredAt = occurredAt
        self.attributes = attributes
    }
}

public extension CueEventRecord {
    var kind: CueEventKind? { CueEventKind(rawValue: name) }

    static func segmentStart(
        occurredAt: Date = Date(),
        segmentId: String,
        kind: WorkoutSegmentKind,
        setIndex: Int
    ) -> Self {
        .init(
            name: CueEventKind.segmentStart.rawValue,
            occurredAt: occurredAt,
            attributes: [
                "segment": segmentId,
                "kind": kind.rawValue,
                "set": String(setIndex)
            ]
        )
    }

    static func workToRest(occurredAt: Date = Date(), from: String, to: String) -> Self {
        .init(
            name: CueEventKind.workToRest.rawValue,
            occurredAt: occurredAt,
            attributes: ["from": from, "to": to]
        )
    }

    static func restToWork(occurredAt: Date = Date(), from: String, to: String) -> Self {
        .init(
            name: CueEventKind.restToWork.rawValue,
            occurredAt: occurredAt,
            attributes: ["from": from, "to": to]
        )
    }

    static func last3s(occurredAt: Date = Date(), segmentId: String) -> Self {
        .init(
            name: CueEventKind.last3s.rawValue,
            occurredAt: occurredAt,
            attributes: ["segment": segmentId]
        )
    }

    static func paused(occurredAt: Date = Date()) -> Self {
        .init(name: CueEventKind.paused.rawValue, occurredAt: occurredAt)
    }

    static func resumed(occurredAt: Date = Date()) -> Self {
        .init(name: CueEventKind.resumed.rawValue, occurredAt: occurredAt)
    }

    static func completed(occurredAt: Date = Date()) -> Self {
        .init(name: CueEventKind.completed.rawValue, occurredAt: occurredAt)
    }
}
