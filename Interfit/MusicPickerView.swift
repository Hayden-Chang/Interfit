import SwiftUI
import Shared

#if canImport(MusicKit)
import MusicKit
#endif
#if os(iOS)
import UIKit
#endif

struct MusicPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onPick: ((MusicSelection) -> Void)?
    let allowedTypes: Set<MusicSelectionType>

    @State private var query: String = ""
    @State private var recents: [MusicSelection] = MusicRecentsStore.load()
    @State private var pendingSelection: MusicSelection?
    @State private var previewErrorMessage: String?

    #if canImport(MusicKit)
    @State private var authStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @State private var isRequestingAuth: Bool = false
    @State private var isSearching: Bool = false
    @State private var searchResults: [MusicSelection] = []
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var myPlaylists: [MusicSelection] = []
    @State private var isLoadingMyPlaylists: Bool = false
    @State private var myPlaylistsError: String?

    @State private var expandedPlaylistExternalId: String?
    @State private var playlistTracksByPlaylistId: [String: [MusicSelection]] = [:]
    @State private var loadingPlaylistExternalId: String?
    @State private var playlistTracksErrorByPlaylistId: [String: String] = [:]
    #endif

    init(
        allowedTypes: Set<MusicSelectionType> = [.track, .album, .playlist],
        onPick: ((MusicSelection) -> Void)? = nil
    ) {
        self.allowedTypes = allowedTypes
        self.onPick = onPick
    }

    var body: some View {
        List {
            if !isAuthorized {
                deniedSection
            } else {
                pickerSections
            }
        }
        .navigationTitle("Music Picker")
        .onAppear { refreshAuthorizationStatus() }
        .onChange(of: query) { _ in
            scheduleSearch()
        }
        .onDisappear {
            #if canImport(MusicKit)
            searchTask?.cancel()
            searchTask = nil
            #endif
        }
        #if canImport(MusicKit)
        .task(id: authStatus) {
            guard authStatus == .authorized else { return }
            guard allowedTypes.contains(.playlist) else { return }
            await loadMyPlaylistsIfNeeded()
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    guard let pendingSelection else {
                        dismiss()
                        return
                    }
                    commitSelectionAndDismiss(pendingSelection)
                }
            }
        }
    }

    private var isAuthorized: Bool {
        #if canImport(MusicKit)
        return authStatus == .authorized
        #else
        return false
        #endif
    }

    private var deniedSection: some View {
        Section("Music Unavailable") {
            Text(deniedMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
            #if canImport(MusicKit)
            if authStatus == .notDetermined {
                Button {
                    Task { await requestAuthorization() }
                } label: {
                    if isRequestingAuth {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Requesting…")
                        }
                    } else {
                        Text("Request Music Access")
                    }
                }
                .disabled(isRequestingAuth)
            } else if authStatus == .denied || authStatus == .restricted {
                Button("Open Settings") { openSettings() }
            }
            #else
            Button("Open Settings") { openSettings() }
            #endif
            Button("Not now", role: .cancel) { dismiss() }
        }
    }

    private var deniedMessage: String {
        #if canImport(MusicKit)
        switch authStatus {
        case .notDetermined:
            return "Music access hasn’t been requested yet. Tap “Request Music Access” to enable Apple Music playback."
        case .denied:
            return "Music access is denied. You can still train with cues only."
        case .restricted:
            return "Music access is restricted on this device. You can still train with cues only."
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Music access status is unknown. You can still train with cues only."
        }
        #else
        return "MusicKit is unavailable on this platform. You can still train with cues only."
        #endif
    }

    private var pickerSections: some View {
        Group {
            Section("Search") {
                TextField("搜索歌曲或歌手", text: $query)

                if let previewErrorMessage {
                    Text(previewErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if canImport(MusicKit)
                if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Searching…")
                    }
                } else if let searchError {
                    Text(searchError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, searchResults.isEmpty {
                    Text("No results.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(searchResults, id: \.externalId) { selection in
                        selectableMusicRow(selection, showMetadata: true)
                    }
                }
                #else
                Text("Search is unavailable on this platform.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }

            Section("Recent") {
                let filteredRecents = recents.filter { allowedTypes.contains($0.type) }
                if filteredRecents.isEmpty {
                    Text("No recents yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredRecents, id: \.externalId) { selection in
                        selectableMusicRow(selection, showMetadata: false)
                    }
                }
            }

            Section("My playlists") {
                #if canImport(MusicKit)
                if !allowedTypes.contains(.playlist) {
                    Text("Playlists are not available for this selection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isLoadingMyPlaylists {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading…")
                    }
                } else if let myPlaylistsError {
                    Text(myPlaylistsError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if myPlaylists.isEmpty {
                    Text("No playlists found.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(myPlaylists, id: \.externalId) { playlist in
                        playlistRow(playlist)
                    }
                }

                if allowedTypes.contains(.playlist) {
                    Button("Reload") {
                        Task { await reloadMyPlaylists() }
                    }
                }
                #else
                Text("My Playlists are unavailable on this platform.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
    }

    private func selectableMusicRow(_ selection: MusicSelection, showMetadata: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.displayTitle)
                if showMetadata {
                    Text("\(selection.source.rawValue) • \(selection.type.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Play") {
                previewSelection(selection)
            }
            .buttonStyle(.bordered)

            Button(isPendingSelection(selection) ? "Selected" : "Select") {
                pendingSelection = selection
            }
            .buttonStyle(.borderedProminent)
        }
    }

    #if canImport(MusicKit)
    private func playlistRow(_ playlist: MusicSelection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    togglePlaylistExpanded(playlist)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expandedPlaylistExternalId == playlist.externalId ? "chevron.down" : "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(playlist.displayTitle)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Play") {
                    previewSelection(playlist)
                }
                .buttonStyle(.bordered)

                Button(isPendingSelection(playlist) ? "Selected" : "Select") {
                    pendingSelection = playlist
                }
                .buttonStyle(.borderedProminent)
            }

            if expandedPlaylistExternalId == playlist.externalId {
                if loadingPlaylistExternalId == playlist.externalId {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading tracks…")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else if let error = playlistTracksErrorByPlaylistId[playlist.externalId] {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let tracks = playlistTracksByPlaylistId[playlist.externalId], !tracks.isEmpty {
                    ForEach(tracks, id: \.externalId) { track in
                        selectableMusicRow(track, showMetadata: false)
                            .padding(.leading, 20)
                    }
                } else {
                    Text("No playable tracks found.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    #endif

    private func isPendingSelection(_ selection: MusicSelection) -> Bool {
        guard let pendingSelection else { return false }
        return pendingSelection.isEquivalent(to: selection)
    }

    private func previewSelection(_ selection: MusicSelection) {
        Task {
            do {
                try await MusicPlaybackClient.apply(selection: selection)
                await MainActor.run {
                    previewErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    previewErrorMessage = "Couldn’t play this right now. Try another item or check Apple Music availability."
                }
            }
        }
    }

    private func commitSelectionAndDismiss(_ selection: MusicSelection) {
        recents = MusicRecentsStore.record(selection: selection, current: recents)
        onPick?(selection)
        dismiss()
    }

    private func refreshAuthorizationStatus() {
        #if canImport(MusicKit)
        authStatus = MusicAuthorization.currentStatus
        #endif
    }

    private func requestAuthorization() async {
        #if canImport(MusicKit)
        guard !isRequestingAuth else { return }
        await MainActor.run { isRequestingAuth = true }
        defer { Task { @MainActor in isRequestingAuth = false } }
        _ = await MusicAuthorization.request()
        await MainActor.run { refreshAuthorizationStatus() }
        #endif
    }

    private func scheduleSearch() {
        #if canImport(MusicKit)
        searchTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            isSearching = false
            searchError = nil
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                isSearching = true
                searchError = nil
            }

            do {
                let results = try await MusicSearchClient.search(term: term, allowedTypes: allowedTypes, limit: 25)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    searchError = nil
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                    searchError = "Couldn’t search Apple Music right now."
                }
            }
        }
        #endif
    }

    #if canImport(MusicKit)
    private func loadMyPlaylistsIfNeeded() async {
        guard myPlaylists.isEmpty else { return }
        await reloadMyPlaylists()
    }

    private func reloadMyPlaylists() async {
        guard !isLoadingMyPlaylists else { return }

        await MainActor.run {
            isLoadingMyPlaylists = true
            myPlaylistsError = nil
        }
        defer { Task { @MainActor in isLoadingMyPlaylists = false } }

        do {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 100
            let response = try await request.response()

            let selections: [MusicSelection] = response.items.map { playlist in
                MusicSelection(
                    source: .localLibrary,
                    type: .playlist,
                    externalId: playlist.id.rawValue,
                    displayTitle: playlist.name,
                    playMode: .continue
                )
            }

            let normalized = MusicSelectionLibrary.normalizedPlaylists(from: selections, maxCount: 100)
            await MainActor.run {
                myPlaylists = normalized
            }
        } catch {
            await MainActor.run {
                myPlaylists = []
                myPlaylistsError = "Couldn’t load playlists. You can still train with cues only."
            }
        }
    }

    private func togglePlaylistExpanded(_ playlist: MusicSelection) {
        if expandedPlaylistExternalId == playlist.externalId {
            expandedPlaylistExternalId = nil
            return
        }

        expandedPlaylistExternalId = playlist.externalId
        if playlistTracksByPlaylistId[playlist.externalId] != nil { return }

        Task {
            await loadTracksForPlaylist(playlistExternalId: playlist.externalId)
        }
    }

    private func loadTracksForPlaylist(playlistExternalId: String) async {
        guard loadingPlaylistExternalId != playlistExternalId else { return }

        await MainActor.run {
            loadingPlaylistExternalId = playlistExternalId
            playlistTracksErrorByPlaylistId[playlistExternalId] = nil
        }
        defer {
            Task { @MainActor in
                if loadingPlaylistExternalId == playlistExternalId {
                    loadingPlaylistExternalId = nil
                }
            }
        }

        do {
            var request = MusicLibraryRequest<Playlist>()
            request.filter(matching: \.id, equalTo: MusicItemID(playlistExternalId))
            request.limit = 1
            let response = try await request.response()

            guard let playlist = response.items.first else {
                await MainActor.run {
                    playlistTracksByPlaylistId[playlistExternalId] = []
                    playlistTracksErrorByPlaylistId[playlistExternalId] = "Playlist not found in library."
                }
                return
            }

            let expanded = try await playlist.with([.tracks])
            let tracks = expanded.tracks ?? []

            var selections: [MusicSelection] = []
            selections.reserveCapacity(tracks.count)

            for item in tracks {
                switch item {
                case .song(let song):
                    guard allowedTypes.contains(.track) else { continue }
                    selections.append(
                        MusicSelection(
                            source: .localLibrary,
                            type: .track,
                            externalId: song.id.rawValue,
                            displayTitle: song.title,
                            artworkUrl: song.artwork?.url(width: 256, height: 256),
                            playMode: .continue
                        )
                    )
                default:
                    continue
                }
            }

            let deduped = Array(Dictionary(grouping: selections, by: \.externalId).compactMap { $0.value.first })

            await MainActor.run {
                playlistTracksByPlaylistId[playlistExternalId] = deduped
                playlistTracksErrorByPlaylistId[playlistExternalId] = nil
            }
        } catch {
            await MainActor.run {
                playlistTracksByPlaylistId[playlistExternalId] = []
                playlistTracksErrorByPlaylistId[playlistExternalId] = "Couldn’t load tracks for this playlist."
            }
        }
    }
    #endif

    private func openSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

private enum MusicRecentsStore {
    private static let key = "interfit.music.recents.v1"
    private static let maxCount = 10

    static func load() -> [MusicSelection] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([MusicSelection].self, from: data)) ?? []
    }

    static func record(selection: MusicSelection, current: [MusicSelection]) -> [MusicSelection] {
        var next = current.filter { !$0.isEquivalent(to: selection) }
        next.insert(selection, at: 0)
        if next.count > maxCount { next = Array(next.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return next
    }
}

#Preview {
    NavigationStack { MusicPickerView() }
}
