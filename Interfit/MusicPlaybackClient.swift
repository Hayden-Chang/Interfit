import Foundation
import Combine
import Shared

#if canImport(MusicKit)
import MusicKit

@MainActor
final class MusicPlaybackClient: ObservableObject {
    static let shared = MusicPlaybackClient()

    struct NowPlayingDisplay: Sendable, Equatable {
        let title: String
        let artist: String
    }

    enum Error: Swift.Error {
        case unsupportedSource
        case authorizationDenied
        case authorizationRestricted
        case notSubscribed
        case itemNotFound
        case developerTokenConfiguration
    }

    private var lastSelection: MusicSelection?
    private var isPlaybackOwnedByInterfit: Bool = false
    private var savedTrackProgress: [String: TimeInterval] = [:]
    private var isCatalogAccessDisabled = false
    private var resolvedSongsByExternalId: [String: Song] = [:]
    private var resolvedAlbumsByExternalId: [String: Album] = [:]
    private var resolvedPlaylistsByExternalId: [String: Playlist] = [:]
    private var prewarmedSelectionExternalIds: Set<String> = []
    @Published private(set) var nowPlayingDisplay: NowPlayingDisplay?

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

    static func prewarm(selections: [MusicSelection]) async {
        await shared.prewarm(selections: selections)
    }

    static func pauseIfOwnedByInterfitForAppTermination() {
        shared.pauseIfOwnedByInterfitForAppTermination()
    }

    nonisolated static func classify(_ error: Swift.Error) -> PlaybackFailureKind {
        if let e = error as? Error {
            switch e {
            case .authorizationDenied, .developerTokenConfiguration:
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
        if lower.contains("client not found") || lower.contains("40402") {
            return .permission
        }
        if lower.contains("developertokenrequestfailed") || lower.contains("token service") {
            return .permission
        }
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
        guard selection.source == .appleMusic || selection.source == .localLibrary else {
            throw Error.unsupportedSource
        }

        let player = SystemMusicPlayer.shared
        let isSameSelectionAsLast = lastSelection?.isEquivalent(to: selection) == true
        var displayCandidate = nowPlayingDisplay

        if !isSameSelectionAsLast {
            try await ensureAuthorizedAndSubscribed()

            if let previous = lastSelection,
               previous.type == .track,
               previous.externalId != selection.externalId
            {
                savedTrackProgress[previous.externalId] = max(0, player.playbackTime)
            }

            switch selection.type {
            case .track:
                displayCandidate = try await queueTrack(selection, player: player)
            case .album:
                displayCandidate = try await queueAlbum(selection, player: player)
            case .playlist:
                displayCandidate = try await queuePlaylist(selection, player: player)
            }
        }

        try await applyDirective(selection.playMode.directiveOnSegmentStart)
        try await player.play()
        isPlaybackOwnedByInterfit = true
        lastSelection = selection
        nowPlayingDisplay = displayCandidate ?? Self.makeNowPlayingDisplay(title: selection.displayTitle, artist: nil)
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
        guard isPlaybackOwnedByInterfit else { return }
        let player = SystemMusicPlayer.shared

        pausePlayerAndSnapshotTrackProgress(player)
    }

    func resume() async {
        guard isPlaybackOwnedByInterfit else { return }
        let player = SystemMusicPlayer.shared
        try? await player.play()
    }

    func stop() async {
        guard isPlaybackOwnedByInterfit else { return }
        let player = SystemMusicPlayer.shared
        pausePlayerAndSnapshotTrackProgress(player)
        isPlaybackOwnedByInterfit = false
        lastSelection = nil
        nowPlayingDisplay = nil
    }

    func pauseIfOwnedByInterfitForAppTermination() {
        guard isPlaybackOwnedByInterfit else { return }
        let player = SystemMusicPlayer.shared
        pausePlayerAndSnapshotTrackProgress(player)
    }

    func prewarm(selections: [MusicSelection]) async {
        let candidates = selections.filter { selection in
            selection.source == .appleMusic
                && !selection.externalId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !candidates.isEmpty else { return }
        _ = SystemMusicPlayer.shared
        do {
            try await ensureAuthorizedAndSubscribed()
        } catch {
            return
        }

        for selection in candidates {
            guard !prewarmedSelectionExternalIds.contains(selection.externalId) else { continue }
            do {
                try await resolveSelection(selection)
                prewarmedSelectionExternalIds.insert(selection.externalId)
            } catch {
                continue
            }
        }
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

        // Do not call `MusicSubscription.current` here.
        // In some provisioning states it may trigger developer-token bootstrap and
        // produce repeated -8200/40402 logs even for local-library playback paths.
    }

    private func resolveSelection(_ selection: MusicSelection) async throws {
        switch selection.type {
        case .track:
            _ = try await resolveTrack(selection)
        case .album:
            _ = try await resolveAlbum(selection)
        case .playlist:
            _ = try await resolvePlaylist(selection)
        }
    }

    private func resolveTrack(_ selection: MusicSelection) async throws -> Song {
        if let cached = resolvedSongsByExternalId[selection.externalId] {
            return cached
        }

        let id = MusicItemID(selection.externalId)
        var song: Song?

        switch selection.source {
        case .appleMusic:
            if isCatalogAccessDisabled {
                throw Error.developerTokenConfiguration
            }
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
                let response = try await request.response()
                song = response.items.first
            } catch {
                if isDeveloperTokenConfigurationError(error) {
                    isCatalogAccessDisabled = true
                    throw Error.developerTokenConfiguration
                }
                throw error
            }
        case .localLibrary:
            if let librarySong = try? await fetchLibrarySong(id: id) {
                song = librarySong
            }
        case .none:
            break
        }

        guard let song else {
            throw Error.itemNotFound
        }

        resolvedSongsByExternalId[selection.externalId] = song
        return song
    }

    private func resolveAlbum(_ selection: MusicSelection) async throws -> Album {
        if let cached = resolvedAlbumsByExternalId[selection.externalId] {
            return cached
        }

        let id = MusicItemID(selection.externalId)
        var album: Album?

        switch selection.source {
        case .appleMusic:
            if isCatalogAccessDisabled {
                throw Error.developerTokenConfiguration
            }
            do {
                let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
                let response = try await request.response()
                album = response.items.first
            } catch {
                if isDeveloperTokenConfigurationError(error) {
                    isCatalogAccessDisabled = true
                    throw Error.developerTokenConfiguration
                }
                throw error
            }
        case .localLibrary:
            if let libraryAlbum = try? await fetchLibraryAlbum(id: id) {
                album = libraryAlbum
            }
        case .none:
            break
        }

        guard let album else {
            throw Error.itemNotFound
        }

        resolvedAlbumsByExternalId[selection.externalId] = album
        return album
    }

    private func resolvePlaylist(_ selection: MusicSelection) async throws -> Playlist {
        if let cached = resolvedPlaylistsByExternalId[selection.externalId] {
            return cached
        }

        let id = MusicItemID(selection.externalId)
        var playlist: Playlist?

        switch selection.source {
        case .appleMusic:
            if isCatalogAccessDisabled {
                throw Error.developerTokenConfiguration
            }
            do {
                let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id)
                let response = try await request.response()
                playlist = response.items.first
            } catch {
                if isDeveloperTokenConfigurationError(error) {
                    isCatalogAccessDisabled = true
                    throw Error.developerTokenConfiguration
                }
                throw error
            }
        case .localLibrary:
            if let libraryPlaylist = try? await fetchLibraryPlaylist(id: id) {
                playlist = libraryPlaylist
            }
        case .none:
            break
        }

        guard let playlist else {
            throw Error.itemNotFound
        }

        resolvedPlaylistsByExternalId[selection.externalId] = playlist
        return playlist
    }

    private func queueTrack(_ selection: MusicSelection, player: SystemMusicPlayer) async throws -> NowPlayingDisplay {
        let song = try await resolveTrack(selection)

        player.queue = [song]
        player.state.repeatMode = .one

        // Restore saved progress for this track
        if let saved = savedTrackProgress[selection.externalId], saved > 0 {
            player.playbackTime = saved
        } else {
            player.playbackTime = 0
        }

        player.state.shuffleMode = .off
        return Self.makeNowPlayingDisplay(title: song.title, artist: song.artistName)
    }

    private func queueAlbum(_ selection: MusicSelection, player: SystemMusicPlayer) async throws -> NowPlayingDisplay {
        let album = try await resolveAlbum(selection)

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

        return Self.makeNowPlayingDisplay(title: album.title, artist: album.artistName)
    }

    private func queuePlaylist(_ selection: MusicSelection, player: SystemMusicPlayer) async throws -> NowPlayingDisplay {
        let playlist = try await resolvePlaylist(selection)

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

        return Self.makeNowPlayingDisplay(title: playlist.name, artist: nil)
    }

    private func fetchLibrarySong(id: MusicItemID) async throws -> Song? {
        var request = MusicLibraryRequest<Song>()
        request.filter(matching: \.id, equalTo: id)
        request.limit = 1
        let response = try await request.response()
        return response.items.first
    }

    private func fetchLibraryAlbum(id: MusicItemID) async throws -> Album? {
        var request = MusicLibraryRequest<Album>()
        request.filter(matching: \.id, equalTo: id)
        request.limit = 1
        let response = try await request.response()
        return response.items.first
    }

    private func fetchLibraryPlaylist(id: MusicItemID) async throws -> Playlist? {
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: id)
        request.limit = 1
        let response = try await request.response()
        return response.items.first
    }

    private func isDeveloperTokenConfigurationError(_ error: Swift.Error) -> Bool {
        let lower = String(describing: error).lowercased()
        return lower.contains("developertokenrequestfailed")
            || lower.contains("client not found")
            || lower.contains("40402")
            || lower.contains("developer token")
    }

    private func pausePlayerAndSnapshotTrackProgress(_ player: SystemMusicPlayer) {
        if let selection = lastSelection, selection.type == .track {
            savedTrackProgress[selection.externalId] = max(0, player.playbackTime)
        }
        player.pause()
    }

    private static func makeNowPlayingDisplay(title: String, artist: String?) -> NowPlayingDisplay {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = (artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return .init(
            title: trimmedTitle.isEmpty ? "Unknown Track" : trimmedTitle,
            artist: trimmedArtist.isEmpty ? "Unknown Artist" : trimmedArtist
        )
    }
}

#else

@MainActor
final class MusicPlaybackClient: ObservableObject {
    static let shared = MusicPlaybackClient()

    struct NowPlayingDisplay: Sendable, Equatable {
        let title: String
        let artist: String
    }

    @Published private(set) var nowPlayingDisplay: NowPlayingDisplay?

    private init() {}

    static func apply(selection _: MusicSelection) async throws {}

    static func applyDirective(_ directive: MusicPlaybackDirective) async throws {
        _ = directive
    }

    static func pause() async {}

    static func resume() async {}

    static func stop() async {}

    static func prewarm(selections _: [MusicSelection]) async {}

    static func pauseIfOwnedByInterfitForAppTermination() {}

    nonisolated static func classify(_ error: Swift.Error) -> PlaybackFailureKind {
        _ = error
        return .unknown
    }
}

#endif
