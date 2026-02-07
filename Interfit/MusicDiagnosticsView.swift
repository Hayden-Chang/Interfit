import SwiftUI

#if canImport(MusicKit)
import MusicKit
#endif

struct MusicDiagnosticsView: View {
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

