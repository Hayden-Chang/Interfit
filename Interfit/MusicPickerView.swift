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

    @State private var query: String = ""
    @State private var recents: [MusicSelection] = MusicRecentsStore.load()

    init(onPick: ((MusicSelection) -> Void)? = nil) {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var isAuthorized: Bool {
        #if canImport(MusicKit)
        return MusicAuthorization.currentStatus == .authorized
        #else
        return false
        #endif
    }

    private var deniedSection: some View {
        Section("Music Unavailable") {
            Text(deniedMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Open Settings") { openSettings() }
            Button("Not now", role: .cancel) { dismiss() }
        }
    }

    private var deniedMessage: String {
        #if canImport(MusicKit)
        switch MusicAuthorization.currentStatus {
        case .notDetermined:
            return "Music access hasn’t been requested yet. You can continue training with cues only."
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
            Section("Search (placeholder)") {
                TextField("Search", text: $query)
                ForEach(mockSearchResults, id: \.externalId) { selection in
                    Button {
                        pick(selection)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(selection.displayTitle)
                            Text("\(selection.source.rawValue) • \(selection.type.rawValue)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Recent") {
                if recents.isEmpty {
                    Text("No recents yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recents, id: \.externalId) { selection in
                        Button {
                            pick(selection)
                        } label: {
                            Text(selection.displayTitle)
                        }
                    }
                }
            }

            Section("My Playlists (placeholder)") {
                Button { pick(mockPlaylist(title: "My Playlist")) } label: { Text("My Playlist") }
                Button { pick(mockPlaylist(title: "Favorites")) } label: { Text("Favorites") }
            }
        }
    }

    private var mockSearchResults: [MusicSelection] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return [
            MusicSelection(source: .appleMusic, type: .track, externalId: "mock.track.\(q)", displayTitle: "Track: \(q)", playMode: .continue),
            MusicSelection(source: .appleMusic, type: .album, externalId: "mock.album.\(q)", displayTitle: "Album: \(q)", playMode: .continue),
        ]
    }

    private func mockPlaylist(title: String) -> MusicSelection {
        MusicSelection(source: .appleMusic, type: .playlist, externalId: "mock.playlist.\(title)", displayTitle: title, playMode: .continue)
    }

    private func pick(_ selection: MusicSelection) {
        recents = MusicRecentsStore.record(selection: selection, current: recents)
        onPick?(selection)
        dismiss()
    }

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
