import Foundation

public enum MusicSource: String, Sendable, Codable, Hashable {
    case none
    case appleMusic
    case localLibrary
}

public enum MusicSelectionType: String, Sendable, Codable, Hashable {
    case track
    case playlist
    case album
}

public enum MusicPlayMode: String, Sendable, Codable, Hashable {
    case `continue`
    case restartOnSegment = "restart_on_segment"
    case shuffleOnSegment = "shuffle_on_segment"
}

/// Music selection metadata attached to a plan/session (2.2.x).
///
/// Equality semantics intentionally ignore display fields.
public struct MusicSelection: Sendable, Codable, Hashable {
    public var source: MusicSource
    public var type: MusicSelectionType
    public var externalId: String
    public var displayTitle: String
    public var artworkUrl: URL?
    public var playMode: MusicPlayMode

    public init(
        source: MusicSource,
        type: MusicSelectionType,
        externalId: String,
        displayTitle: String,
        artworkUrl: URL? = nil,
        playMode: MusicPlayMode
    ) {
        self.source = source
        self.type = type
        self.externalId = externalId
        self.displayTitle = displayTitle
        self.artworkUrl = artworkUrl
        self.playMode = playMode
    }

    public func isEquivalent(to other: MusicSelection) -> Bool {
        source == other.source
            && type == other.type
            && externalId == other.externalId
            && playMode == other.playMode
    }

    public static func == (lhs: MusicSelection, rhs: MusicSelection) -> Bool {
        lhs.isEquivalent(to: rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(type)
        hasher.combine(externalId)
        hasher.combine(playMode)
    }
}

