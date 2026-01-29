import Foundation
import Persistence

enum ICloudBackupStatus: Sendable, Equatable {
    case disabled
    case containerUnavailable
    case succeeded(path: String)
    case failed(message: String)
}

@MainActor
final class ICloudBackupService: ObservableObject {
    @Published private(set) var lastStatus: ICloudBackupStatus?

    private let store: CoreDataPersistenceStore
    private let fileManager: FileManager
    private let defaults: UserDefaults

    init(
        store: CoreDataPersistenceStore = CoreDataPersistenceStore(),
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.fileManager = fileManager
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    func runBackupIfEnabled() async {
        guard isEnabled else {
            lastStatus = .disabled
            return
        }
        lastStatus = await runBackup()
    }

    func runBackup() async -> ICloudBackupStatus {
        do {
            guard let container = fileManager.url(forUbiquityContainerIdentifier: nil) else {
                return .containerUnavailable
            }

            let docs = container.appendingPathComponent("Documents", isDirectory: true)
            let dir = docs.appendingPathComponent("InterfitBackups", isDirectory: true)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

            let bundle = await store.exportBackupBundle()
            let data = try JSONEncoder.backup.encode(bundle)

            let stamp = Self.filenameTimestampFormatter.string(from: Date())
            let url = dir.appendingPathComponent("interfit_icloud_backup_\(stamp).json")
            try data.write(to: url, options: [.atomic])
            return .succeeded(path: url.path)
        } catch {
            return .failed(message: String(describing: error))
        }
    }

    private static let enabledKey = "interfit.backup.icloudEnabled"

    private static let filenameTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

private extension JSONEncoder {
    static var backup: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}

