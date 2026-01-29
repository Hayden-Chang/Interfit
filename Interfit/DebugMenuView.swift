#if DEBUG
import SwiftUI
import Persistence

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var statusText: String?
    @State private var path = NavigationPath()
    @State private var alertTitle: String?
    @State private var alertMessage: String?
    @State private var isShowingAlert: Bool = false
    @StateObject private var iCloudBackup = ICloudBackupService()
    @AppStorage("interfit.backup.icloudEnabled") private var isICloudBackupEnabled: Bool = false
    @AppStorage("interfit.analytics.optIn") private var isAnalyticsOptIn: Bool = true

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Navigation") {
                    NavigationLink("Modules demo") {
                        ModulesDemoView()
                    }
                    NavigationLink("Plan editor (Mode A)") {
                        PlanEditorView(plan: nil)
                    }
                    NavigationLink("Plan editor (Mode B)") {
                        PlanEditorView(plan: nil, startInModeB: true)
                    }
                    NavigationLink("Plans") {
                        PlansListView()
                    }
                    NavigationLink("History") {
                        SessionHistoryListView()
                    }
                    NavigationLink("Music access (explainer)") {
                        MusicPermissionExplainerView()
                    }
                    NavigationLink("Music picker (placeholder)") {
                        MusicPickerView()
                    }
                }

                Section("Data") {
                    Button("Seed demo data") {
                        run(action: "Seed demo data", label: "Seeding demo data…", destination: .plans) {
                            await DemoDataSeeder.seedIfRequested(arguments: ["-seedDemoData"])
                        }
                    }
                    .disabled(isRunning)

                    Button(role: .destructive) {
                        run(action: "Reset all data", label: "Resetting all data…", destination: nil) {
                            await DemoDataSeeder.resetIfRequested(arguments: ["-resetDemoData"])
                        }
                    } label: {
                        Text("Reset all data")
                    }
                    .disabled(isRunning)
                }

                Section("Smoke") {
                    Button("Seed smoke flow") {
                        run(action: "Seed smoke flow", label: "Seeding smoke flow…", destination: .history) {
                            await SmokeFlowSeeder.seedIfRequested(arguments: ["-autoSmokeFlow"])
                        }
                    }
                    .disabled(isRunning)
                }

                Section("Backup") {
                    Button("Export backup (JSON)") {
                        exportBackup()
                    }
                    .disabled(isRunning)

                    Button("Import backup (JSON)") {
                        importBackup()
                    }
                    .disabled(isRunning)
                }

                Section("iCloud Backup") {
                    Toggle("Enable iCloud backup", isOn: $isICloudBackupEnabled)

                    Button("Run iCloud backup now") {
                        runICloudBackupOnce()
                    }
                    .disabled(isRunning)

                    if let status = iCloudBackup.lastStatus {
                        Text(iCloudStatusText(status))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Analytics") {
                    Toggle("Allow anonymous usage data", isOn: $isAnalyticsOptIn)

                    Button("Clear analytics events") {
                        clearAnalyticsEvents()
                    }
                    .disabled(isRunning)

                    Text("Saved in Application Support as: \(AnalyticsEventRecorder.fileName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let statusText {
                    Section("Status") {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Debug")
            .alert(alertTitle ?? "Info", isPresented: $isShowingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isRunning)
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .plans:
                    PlansListView()
                case .history:
                    SessionHistoryListView()
                }
            }
        }
    }

    private enum Destination: Hashable {
        case plans
        case history
    }

    private func exportBackup() {
        statusText = "Exporting backup…"
        isRunning = true
        Task {
            do {
                let store = CoreDataPersistenceStore()
                let bundle = await store.exportBackupBundle()
                let data = try JSONEncoder.backup.encode(bundle)
                let url = try backupFileURL(filename: "interfit_backup_latest.json")
                try data.write(to: url, options: [.atomic])

                let stamp = Self.filenameTimestampFormatter.string(from: Date())
                let stamped = try backupFileURL(filename: "interfit_backup_\(stamp).json")
                try data.write(to: stamped, options: [.atomic])

                await MainActor.run {
                    statusText = "Exported backup. (Printed file path in console.)"
                    alertTitle = "Exported"
                    alertMessage = "Wrote:\n\(url.path)\n\nand:\n\(stamped.path)"
                    isShowingAlert = true
                    isRunning = false
                }
                print("[Interfit] Backup exported to:", url.path)
            } catch {
                await MainActor.run {
                    statusText = "Export failed."
                    alertTitle = "Export failed"
                    alertMessage = String(describing: error)
                    isShowingAlert = true
                    isRunning = false
                }
            }
        }
    }

    private func importBackup() {
        statusText = "Importing backup…"
        isRunning = true
        Task {
            do {
                let store = CoreDataPersistenceStore()
                let url = try backupImportCandidateURL()
                let data = try Data(contentsOf: url)
                let bundle = try JSONDecoder().decode(InterfitBackupBundle.self, from: data)
                try await store.importBackupBundle(bundle, overwrite: true)
                await MainActor.run {
                    statusText = "Imported backup."
                    alertTitle = "Imported"
                    alertMessage = "Imported from:\n\(url.path)"
                    isShowingAlert = true
                    isRunning = false
                }
                print("[Interfit] Backup imported from:", url.path)
            } catch {
                await MainActor.run {
                    statusText = "Import failed."
                    alertTitle = "Import failed"
                    alertMessage = String(describing: error)
                    isShowingAlert = true
                    isRunning = false
                }
            }
        }
    }

    private func runICloudBackupOnce() {
        statusText = "Running iCloud backup…"
        isRunning = true
        Task {
            await iCloudBackup.runBackupIfEnabled()
            await MainActor.run {
                statusText = "iCloud backup attempt finished."
                isRunning = false
            }
        }
    }

    private func iCloudStatusText(_ status: ICloudBackupStatus) -> String {
        switch status {
        case .disabled:
            "Disabled."
        case .containerUnavailable:
            "iCloud container unavailable (entitlement or iCloud account missing)."
        case let .succeeded(path):
            "Succeeded: \(path)"
        case let .failed(message):
            "Failed: \(message)"
        }
    }

    private func clearAnalyticsEvents() {
        statusText = "Clearing analytics events…"
        isRunning = true
        Task {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let url = dir.appendingPathComponent(AnalyticsEventRecorder.fileName)
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                await MainActor.run {
                    statusText = "Cleared analytics events."
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    statusText = "Clear analytics failed."
                    alertTitle = "Clear analytics failed"
                    alertMessage = String(describing: error)
                    isShowingAlert = true
                    isRunning = false
                }
            }
        }
    }

    private struct StoreCounts: Sendable {
        var plans: Int
        var sessions: Int
    }

    private func captureCounts() async -> StoreCounts {
        let store = CoreDataPersistenceStore()
        let planRepo: any PlanRepository = store
        let sessionRepo: any SessionRepository = store

        async let plans = planRepo.fetchAllPlans()
        async let sessions = sessionRepo.fetchAllSessions()
        return await StoreCounts(plans: plans.count, sessions: sessions.count)
    }

    private func statusSummary(action: String, before: StoreCounts, after: StoreCounts) -> String {
        let deltaPlans = after.plans - before.plans
        let deltaSessions = after.sessions - before.sessions

        if deltaPlans == 0, deltaSessions == 0 {
            return "\(action) done. No changes (already seeded?). Totals: Plans \(after.plans), Sessions \(after.sessions)."
        }

        var parts: [String] = []
        if deltaPlans != 0 {
            parts.append("Plans \(deltaPlans >= 0 ? "+" : "")\(deltaPlans)")
        }
        if deltaSessions != 0 {
            parts.append("Sessions \(deltaSessions >= 0 ? "+" : "")\(deltaSessions)")
        }
        let deltaText = parts.joined(separator: ", ")
        return "\(action) done. \(deltaText). Totals: Plans \(after.plans), Sessions \(after.sessions)."
    }

    private func run(
        action: String,
        label: String,
        destination: Destination?,
        operation: @escaping @Sendable () async -> Void
    ) {
        statusText = label
        isRunning = true
        Task {
            let before = await captureCounts()
            await operation()
            let after = await captureCounts()
            await MainActor.run {
                statusText = statusSummary(action: action, before: before, after: after)
                isRunning = false
                if let destination {
                    path = NavigationPath()
                    path.append(destination)
                }
            }
        }
    }

    private func backupFileURL(filename: String) throws -> URL {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    private func backupImportCandidateURL() throws -> URL {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let latest = dir.appendingPathComponent("interfit_backup_latest.json")
        if FileManager.default.fileExists(atPath: latest.path) {
            return latest
        }

        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
        let candidates = items.filter { $0.lastPathComponent.hasPrefix("interfit_backup_") && $0.pathExtension == "json" }
        let sorted = candidates.sorted { (lhs, rhs) in
            let ld = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rd = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return ld > rd
        }
        if let newest = sorted.first {
            return newest
        }

        throw CocoaError(.fileNoSuchFile)
    }

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

#Preview {
    DebugMenuView()
}
#endif
