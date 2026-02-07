import Foundation

public enum MusicResolutionAttempt: Sendable, Equatable {
    case libraryById
    case catalogById
    case libraryByTitleArtist
}

public enum MusicResolutionError: Error, Sendable, Equatable {
    case notFound(attempts: [MusicResolutionAttempt])
}

/// Pure resolution helper used by the app layer to decide which lookup(s) to try for a given selection.
///
/// - Important: This type intentionally does not depend on MusicKit so it can be unit tested deterministically.
public enum MusicItemResolver {
    /// Resolve a playable item using a best-effort strategy:
    /// - Try by ID in the preferred source order (library→catalog or catalog→library).
    /// - If preferred source is `.localLibrary`, and the ID lookups fail, try library by title/artist as a last resort.
    public static func resolve<T: Sendable>(
        preferredSource: MusicSource,
        externalId: String,
        displayTitle: String?,
        displaySubtitle: String?,
        fetchLibraryById: @escaping @Sendable (String) async throws -> T?,
        fetchCatalogById: @escaping @Sendable (String) async throws -> T?,
        fetchLibraryByTitleArtist: @escaping @Sendable (String, String?) async throws -> T?
    ) async throws -> T {
        var attempts: [MusicResolutionAttempt] = []

        func tryLibraryById() async throws -> T? {
            attempts.append(.libraryById)
            return try await fetchLibraryById(externalId)
        }

        func tryCatalogById() async throws -> T? {
            attempts.append(.catalogById)
            return try await fetchCatalogById(externalId)
        }

        switch preferredSource {
        case .localLibrary:
            if let item = try await tryLibraryById() { return item }
            if let item = try await tryCatalogById() { return item }

            let title = (displayTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                attempts.append(.libraryByTitleArtist)
                if let item = try await fetchLibraryByTitleArtist(title, displaySubtitle) { return item }
            }
        case .appleMusic:
            if let item = try await tryCatalogById() { return item }
            if let item = try await tryLibraryById() { return item }
        case .none:
            break
        }

        throw MusicResolutionError.notFound(attempts: attempts)
    }
}

