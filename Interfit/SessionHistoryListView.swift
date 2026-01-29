import SwiftUI
import Shared
import Persistence

struct SessionHistoryListView: View {
    @StateObject private var viewModel = SessionHistoryListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sessions.isEmpty {
                VStack(spacing: 12) {
                    Text("No sessions yet")
                        .font(.headline)
                    Text("Finish a workout to see it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.sessions) { session in
                        NavigationLink {
                            SessionHistoryDetailView(session: session)
                        } label: {
                            SessionHistoryRow(session: session)
                        }
                    }
                }
                .refreshable {
                    await DemoDataSeeder.seedIfRequested()
                    await SmokeFlowSeeder.seedIfRequested()
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("History")
        .task {
            await DemoDataSeeder.seedIfRequested()
            await viewModel.load()
        }
    }
}

@MainActor
final class SessionHistoryListViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var isLoading: Bool = false

    private let repository: any SessionRepository

    init(repository: any SessionRepository = CoreDataPersistenceStore()) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        let fetched = await repository.fetchAllSessions()
        sessions = fetched
        isLoading = false
    }
}

private struct SessionHistoryRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.dateFormatter.string(from: session.startedAt))
                    .font(.headline)
                Spacer()
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SessionTemplateSummaryText(session: session)

            if !eventLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(eventLabels, id: \.self) { label in
                            TagChip(text: label)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statusText: String {
        switch session.status {
        case .completed: "Completed"
        case .ended: "Ended"
        case .paused: "Paused"
        case .running: "Running"
        case .idle: "Idle"
        }
    }

    private var eventLabels: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for event in session.events {
            let label = event.label
            guard !seen.contains(label) else { continue }
            seen.insert(label)
            result.append(label)
            if result.count >= 6 { break }
        }
        return result
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

private struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        SessionHistoryListView()
    }
}
