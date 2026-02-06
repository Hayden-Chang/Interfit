import Foundation
import Shared

#if canImport(MusicKit)
import MusicKit

@MainActor
enum MusicPlaybackClient {
    static func apply(selection: MusicSelection) async throws {
        guard selection.source == .appleMusic else { return }

        let player = SystemMusicPlayer.shared
        let id = MusicItemID(selection.externalId)

        switch selection.type {
        case .track:
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
            let response = try await request.response()
            guard let song = response.items.first else { return }
            player.queue = [song]
        case .album:
            let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
            let response = try await request.response()
            guard let album = response.items.first else { return }
            player.queue = [album]
        case .playlist:
            let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id)
            let response = try await request.response()
            guard let playlist = response.items.first else { return }
            player.queue = [playlist]
        }

        try await player.play()
    }
}

#else

@MainActor
enum MusicPlaybackClient {
    static func apply(selection: MusicSelection) async throws {
        _ = selection
    }
}

#endif
