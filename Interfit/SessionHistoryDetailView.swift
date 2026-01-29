import SwiftUI
import Shared

struct SessionHistoryDetailView: View {
    let session: Session

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Status", value: statusText)
                LabeledContent("Started", value: Self.dateFormatter.string(from: session.startedAt))
                if let endedAt = session.endedAt {
                    LabeledContent("Ended", value: Self.dateFormatter.string(from: endedAt))
                }
                if let snapshot = session.planSnapshot {
                    LabeledContent("Plan", value: snapshot.name)
                }
                LabeledContent("Progress", value: "\(session.completedSets) / \(session.totalSets)")
                SessionTemplateSummaryText(session: session)
            }

            if session.hasOverrides, let overrides = session.overrides {
                Section("Overrides") {
                    if let sets = overrides.setsCount {
                        LabeledContent("Sets override", value: "\(sets)")
                    }
                    if let work = overrides.workSeconds {
                        LabeledContent("Work override", value: "\(work)s")
                    }
                    if let rest = overrides.restSeconds {
                        LabeledContent("Rest override", value: "\(rest)s")
                    }
                    if let music = overrides.musicSelection {
                        LabeledContent("Music override", value: music.displayTitle)
                    }
                    Text("仅本次训练生效，不写回计划。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !eventLabels.isEmpty {
                Section("Event Tags") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(eventLabels, id: \.self) { label in
                            TagChip(text: label)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !session.events.isEmpty {
                Section("Events") {
                    ForEach(Array(session.events.enumerated()), id: \.offset) { _, event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.label)
                                    .font(.headline)
                                Spacer()
                                Text(Self.timeFormatter.string(from: event.occurredAt))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !event.attributes.isEmpty {
                                Text(event.attributesDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Session")
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
            if result.count >= 12 { break }
        }
        return result
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
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

private extension SessionEventRecord {
    var attributesDescription: String {
        let pairs = attributes
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
        return pairs.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        SessionHistoryDetailView(
            session: Session(
                status: .completed,
                startedAt: Date().addingTimeInterval(-12 * 60),
                endedAt: Date(),
                planSnapshot: PlanSnapshot(planId: UUID(), setsCount: 6, workSeconds: 30, restSeconds: 15, name: "Snapshot Plan"),
                completedSets: 6,
                totalSets: 6,
                workSeconds: 30,
                restSeconds: 15,
                events: [
                    .segmentChanged(from: "work#1", to: "rest#1"),
                    .paused(reason: "user"),
                    .resumed(),
                    .completed(),
                ]
            )
        )
    }
}
