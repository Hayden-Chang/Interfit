import SwiftUI

struct CommunityFeedView: View {
    @StateObject private var connectivity = ConnectivityMonitor()
    @StateObject private var viewModel = CommunityFeedViewModel()

    var body: some View {
        List {
            if !connectivity.isOnline {
                Section {
                    Text("Offline. Showing cached summaries only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.summaries.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No cached content")
                            .font(.headline)
                        Text("Connect to the internet to cache community summaries for offline viewing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                Section("Cached Summaries") {
                    ForEach(viewModel.summaries) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Community")
        .task {
            await viewModel.load(isOnline: connectivity.isOnline)
        }
        .onChange(of: connectivity.isOnline) { online in
            Task { await viewModel.load(isOnline: online) }
        }
    }
}

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    @Published private(set) var summaries: [CommunityPostSummary] = []

    private let cache = CommunityCacheStore()

    func load(isOnline: Bool) async {
        let cached = cache.load()

        if isOnline {
            // Placeholder "fetch": until Community/Market is implemented, cache a stable demo set.
            let now = Date()
            let demo: [CommunityPostSummary] = [
                .init(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, title: "Tabata · 8×20s", subtitle: "Free · Cached summary placeholder", cachedAt: now),
                .init(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, title: "Beginner HIIT · 6 sets", subtitle: "Free · Cached summary placeholder", cachedAt: now),
            ]
            cache.save(demo)
            summaries = demo
        } else {
            summaries = cached
        }
    }
}

#Preview {
    NavigationStack {
        CommunityFeedView()
    }
}
