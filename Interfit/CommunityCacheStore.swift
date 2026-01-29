import Foundation

struct CommunityPostSummary: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var subtitle: String
    var cachedAt: Date
}

final class CommunityCacheStore {
    private let defaults: UserDefaults
    private let key = "interfit.community.cachedSummaries.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [CommunityPostSummary] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CommunityPostSummary].self, from: data)) ?? []
    }

    func save(_ summaries: [CommunityPostSummary]) {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        defaults.set(data, forKey: key)
    }
}

