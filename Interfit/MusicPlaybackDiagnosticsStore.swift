import Foundation
import Shared

struct MusicPlaybackDiagnosticEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
    let source: String
    let presentation: MusicPlaybackErrorPresentation
    let message: String
    let failureKind: String
    let itemTitle: String?
    let itemExternalId: String?
    let itemType: String?
    let itemSource: String?
    let entitlementStatus: String
    let authorizationStatus: String
    let subscriptionAvailable: String
    let subscriptionDiagnostic: String?
    let errorDescription: String
}

@MainActor
final class MusicPlaybackDiagnosticsStore: ObservableObject {
    static let shared = MusicPlaybackDiagnosticsStore()

    @Published private(set) var entries: [MusicPlaybackDiagnosticEntry]

    private let defaults: UserDefaults
    private let storageKey = "interfit.musicPlaybackDiagnostics.entries"
    private let maxEntries = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MusicPlaybackDiagnosticEntry].self, from: data)
        {
            self.entries = decoded
        } else {
            self.entries = []
        }
    }

    func recordFailure(source: String, selection: MusicSelection?, error: Swift.Error) {
        let presentation = MusicPlaybackClient.previewErrorPresentation(for: error)
        let description = ErrorDescriptionFormatter.describe(error).trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = MusicPlaybackDiagnosticEntry(
            id: UUID(),
            occurredAt: Date(),
            source: source,
            presentation: presentation,
            message: presentation.message,
            failureKind: MusicPlaybackClient.classify(error).rawValue,
            itemTitle: selection?.displayTitle,
            itemExternalId: selection?.externalId,
            itemType: selection?.type.rawValue,
            itemSource: selection?.source.rawValue,
            entitlementStatus: MusicPlaybackClient.entitlementStatusDescription(),
            authorizationStatus: MusicPlaybackClient.authorizationStatusDescription(),
            subscriptionAvailable: MusicPlaybackClient.subscriptionAvailabilityDescription(),
            subscriptionDiagnostic: MusicPlaybackClient.subscriptionDiagnosticDescription(),
            errorDescription: String(description.prefix(1200))
        )

        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeSubrange(maxEntries...)
        }
        persist()

        NSLog(
            "[MusicPlaybackDiagnostics] source=%@ category=%@ failureKind=%@ itemTitle=%@ itemId=%@ entitlement=%@ auth=%@ subscriptionAvailable=%@ subscriptionDiagnostic=%@ error=%@",
            source,
            presentation.rawValue,
            entry.failureKind,
            selection?.displayTitle ?? "(none)",
            selection?.externalId ?? "(none)",
            entry.entitlementStatus,
            entry.authorizationStatus,
            entry.subscriptionAvailable,
            entry.subscriptionDiagnostic ?? "(none)",
            entry.errorDescription
        )
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
