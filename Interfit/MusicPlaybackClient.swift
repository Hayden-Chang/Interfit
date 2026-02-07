import Foundation
import Shared

#if canImport(MusicKit)
import MusicKit

@MainActor
final class MusicPlaybackClient {
    static let shared = MusicPlaybackClient()

    enum Error: Swift.Error {
        case unsupportedSource
        case authorizationDenied
        case authorizationRestricted
        case notSubscribed
        case itemNotFound
    }

    private var lastSelection: MusicSelection?
    private var savedTrackProgress: [String: TimeInterval] = [:]

    private init() {}

    static func apply(selection: MusicSelection) async throws {
        try await shared.apply(selection: selection)
    }

    static func applyDirective(_ directive: MusicPlaybackDirective) async throws {
        try await shared.applyDirective(directive)
    }

    static func pause() async {
        await shared.pause()
    }

    static func resume() async {
        await shared.resume()
    }

    static func stop() async {
        await shared.stop()
    }

    nonisolated static func classify(_ error: Swift.Error) -> PlaybackFailureKind {
        if let e = error as? Error {
            switch e {
            case .authorizationDenied:
                return .permission
            case .authorizationRestricted:
                return .restriction
            case .notSubscribed, .itemNotFound:
                return .resource
            case .unsupportedSource:
                return .resource
            }
        }

        let lower = String(describing: error).lowercased()
        if lower.contains("not authorized") || lower.contains("permission") || lower.contains("denied") {
            return .permission
        }
        if lower.contains("restricted") {
            return .restriction
        }
        if lower.contains("offline") || lower.contains("network") || lower.contains("timeout") {
            return .offline
        }
        if lower.contains("unavailable") || lower.contains("not found") || lower.contains("subscription") {
            return .resource
        }
        return .unknown
    }

    func apply(selection: MusicSelection) async throws {
        guard selection.source == .appleMusic else {
            throw Error.unsupportedSource
        }

        try await ensureAuthorizedAndSubscribed()

        let player = SystemMusicPlayer.shared

        if let previous = lastSelection,
           previous.type == .track,
           previous.externalId != selection.externalId
        {
            savedTrackProgress[previous.externalId] = max(0, player.playbackTime)
        }

        switch selection.type {
        case .track:
            try await queueTrack(selection, player: player)
        case .album:
            try await queueAlbum(selection, player: player)
        case .playlist:
            try await queuePlaylist(selection, player: player)
        }

        try await applyDirective(selection.playMode.directiveOnSegmentStart)
        try await player.play()
        lastSelection = selection
    }

    func applyDirective(_ directive: MusicPlaybackDirective) async throws {
        let player = SystemMusicPlayer.shared

        switch directive {
        case .none:
            break
        case .restartSelection:
            player.playbackTime = 0
        case .shuffleSelection:
            player.state.shuffleMode = .songs
            player.playbackTime = 0
        }
    }

    func pause() async {
        let player = SystemMusicPlayer.shared

        if let selection = lastSelection, selection.type == .track {
            savedTrackProgress[selection.externalId] = max(0, player.playbackTime)
        }
        player.pause()
    }

    func resume() async {
        let player = SystemMusicPlayer.shared
        try? await player.play()
    }

    func stop() async {
        let player = SystemMusicPlayer.shared
        if let selection = lastSelection, selection.type == .track {
            savedTrackProgress[selection.externalId] = max(0, player.playbackTime)
        }
        player.pause()
    }

    private func ensureAuthorizedAndSubscribed() async throws {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            break
        case .denied:
            throw Error.authorizationDenied
        case .restricted:
            throw Error.authorizationRestricted
        case .notDetermined:
            _ = await MusicAuthorization.request()
            return try await ensureAuthorizedAndSubscribed()
        @unknown default:
            throw Error.authorizationDenied
        }

        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else {
            throw Error.notSubscribed
        }
    }

    private func queueTrack(_ selection: MusicSelection, player: SystemMusicPlayer) async throws {
        let id = MusicItemID(selection.externalId)
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
        let response = try await request.response()
        guard let song = response.items.first else {
            throw Error.itemNotFound
        }
        player.queue = [song]

        player.state.repeatMode = .one

        if selection.playMode == .continue, let saved = savedTrackProgress[selection.externalId], saved > 0 {
            player.playbackTime = saved
        } else {
            player.playbackTime = 0
        }

        player.state.shuffleMode = .off
    }

    private func queueAlbum(_ selection: MusicSelection, player: SystemMusicPlayer) async throws {
        let id = MusicItemID(selection.externalId)
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
        let response = try await request.response()
        guard let album = response.items.first else {
            throw Error.itemNotFound
        }
        player.queue = [album]
        player.state.repeatMode = .all

        switch selection.playMode {
        case .shuffleOnSegment:
            player.state.shuffleMode = .songs
            player.playbackTime = 0
        case .restartOnSegment:
            player.state.shuffleMode = .off
            player.playbackTime = 0
        case .continue:
            player.state.shuffleMode = .off
        }
    }

    private func queuePlaylist(_ selection: MusicSelection, player: SystemMusicPlayer) async throws {
        let id = MusicItemID(selection.externalId)
        let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id)
        let response = try await request.response()
        guard let playlist = response.items.first else {
            throw Error.itemNotFound
        }
        player.queue = [playlist]
        player.state.repeatMode = .all

        switch selection.playMode {
        case .shuffleOnSegment:
            player.state.shuffleMode = .songs
            player.playbackTime = 0
        case .restartOnSegment:
            player.state.shuffleMode = .off
            player.playbackTime = 0
        case .continue:
            player.state.shuffleMode = .off
        }
    }
}

#else

@MainActor
final class MusicPlaybackClient {
    static let shared = MusicPlaybackClient()

    private init() {}

    static func apply(selection _: MusicSelection) async throws {}

    static func applyDirective(_ directive: MusicPlaybackDirective) async throws {
        _ = directive
    }

    static func pause() async {}

    static func resume() async {}

    static func stop() async {}

    nonisolated static func classify(_ error: Swift.Error) -> PlaybackFailureKind {
        _ = error
        return .unknown
    }
}

#endif
