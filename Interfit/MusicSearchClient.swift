import Foundation
import Shared

#if canImport(MusicKit)
import MusicKit

enum MusicSearchClient {
    static func search(term: String, allowedTypes: Set<MusicSelectionType>, limit: Int = 25) async throws -> [MusicSelection] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var types: [any MusicCatalogSearchable.Type] = []
        if allowedTypes.contains(.track) { types.append(Song.self) }
        if allowedTypes.contains(.album) { types.append(Album.self) }
        if allowedTypes.contains(.playlist) { types.append(Playlist.self) }
        guard !types.isEmpty else { return [] }

        var request = MusicCatalogSearchRequest(term: trimmed, types: types)
        request.limit = limit
        let response = try await request.response()

        var selections: [MusicSelection] = []
        selections.reserveCapacity(limit)

        if allowedTypes.contains(.track) {
            for song in response.songs.prefix(limit) {
                selections.append(
                    MusicSelection(
                        source: .appleMusic,
                        type: .track,
                        externalId: song.id.rawValue,
                        displayTitle: song.title,
                        artworkUrl: song.artwork?.url(width: 256, height: 256),
                        playMode: .continue
                    )
                )
            }
        }

        if allowedTypes.contains(.album) {
            for album in response.albums.prefix(limit) {
                selections.append(
                    MusicSelection(
                        source: .appleMusic,
                        type: .album,
                        externalId: album.id.rawValue,
                        displayTitle: album.title,
                        artworkUrl: album.artwork?.url(width: 256, height: 256),
                        playMode: .continue
                    )
                )
            }
        }

        if allowedTypes.contains(.playlist) {
            for playlist in response.playlists.prefix(limit) {
                selections.append(
                    MusicSelection(
                        source: .appleMusic,
                        type: .playlist,
                        externalId: playlist.id.rawValue,
                        displayTitle: playlist.name,
                        artworkUrl: playlist.artwork?.url(width: 256, height: 256),
                        playMode: .continue
                    )
                )
            }
        }

        return selections
    }
}

#else

enum MusicSearchClient {
    static func search(term _: String, allowedTypes _: Set<MusicSelectionType>, limit _: Int = 25) async throws -> [MusicSelection] {
        []
    }
}

#endif

