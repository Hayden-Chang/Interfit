import SwiftUI

#if canImport(MusicKit)
import MusicKit
#endif

struct MusicDiagnosticsView: View {
    @StateObject private var diagnostics = MusicPlaybackDiagnosticsStore.shared

    var body: some View {
        List {
            Section("Status") {
                LabeledContent("Bundle ID") {
                    Text(MusicKitPreflight.bundleIdentifier ?? "(unknown)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                LabeledContent("MusicKit Entitlement") {
                    Text(entitlementText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                #if canImport(MusicKit)
                LabeledContent("Apple Music Authorization") {
                    Text(String(describing: MusicAuthorization.currentStatus))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                #endif
            }

            Section("Summary") {
                Text(MusicKitPreflight.configurationSummary())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("Recent Playback Errors") {
                if diagnostics.entries.isEmpty {
                    Text("No recent playback errors have been recorded on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(diagnostics.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.presentation.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(entry.occurredAt, format: .dateTime.year().month().day().hour().minute().second())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.message)
                                .font(.footnote)

                            Text("source=\(entry.source), failureKind=\(entry.failureKind)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            Text("entitlement=\(entry.entitlementStatus), auth=\(entry.authorizationStatus), subscriptionAvailable=\(entry.subscriptionAvailable)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            if let subscriptionDiagnostic = entry.subscriptionDiagnostic, !subscriptionDiagnostic.isEmpty {
                                Text("subscription=\(subscriptionDiagnostic)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            if let itemTitle = entry.itemTitle, !itemTitle.isEmpty {
                                Text("item=\(itemTitle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            if let itemExternalId = entry.itemExternalId, !itemExternalId.isEmpty {
                                Text("itemId=\(itemExternalId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Text(entry.errorDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }

                    Button("Clear Errors", role: .destructive) {
                        diagnostics.clear()
                    }
                }
            }

            Section("Fix") {
                Text(
                    """
                    1) 确保 Bundle Identifier 与 Apple Developer 后台的 App ID 完全一致
                    2) Xcode → Target → Signing & Capabilities → + Capability → MusicKit
                    3) Apple Developer → Identifiers → (该 App ID) → Capabilities → 启用 MusicKit
                    4) 重新生成/更新 Provisioning Profile（或使用 Xcode 自动签名）
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Music Diagnostics")
    }

    private var entitlementText: String {
        switch MusicKitPreflight.musicUserTokenEntitlementStatus() {
        case .present: "present"
        case .missing: "missing"
        case .unknown: "unknown"
        }
    }
}

#Preview {
    NavigationStack {
        MusicDiagnosticsView()
    }
}
