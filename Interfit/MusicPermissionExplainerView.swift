#if DEBUG
import SwiftUI

#if canImport(MusicKit)
import MusicKit
#endif

struct MusicPermissionExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var statusText: String = "Unknown"
    @State private var isRequesting = false

    var body: some View {
        List {
            Section("Why we ask") {
                Text("Interfit can play music during training. Permission is only requested when you tap the button below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                Text(statusText)
                    .font(.footnote)
            }

            Section {
                Button {
                    Task { await requestAuthorization() }
                } label: {
                    if isRequesting {
                        HStack {
                            ProgressView()
                            Text("Requesting…")
                        }
                    } else {
                        Text("Request Music Access")
                    }
                }
                .disabled(isRequesting)

                Button("Not now", role: .cancel) { dismiss() }
            }
        }
        .navigationTitle("Music Access")
        .onAppear { refreshStatus() }
    }

    private func refreshStatus() {
        #if canImport(MusicKit)
        switch MusicAuthorization.currentStatus {
        case .authorized:
            statusText = "Authorized"
        case .denied:
            statusText = "Denied"
        case .restricted:
            statusText = "Restricted"
        case .notDetermined:
            statusText = "Not Determined"
        @unknown default:
            statusText = "Unknown"
        }
        #else
        statusText = "MusicKit unavailable on this platform"
        #endif
    }

    private func requestAuthorization() async {
        guard !isRequesting else { return }
        await MainActor.run { isRequesting = true }
        defer { Task { @MainActor in isRequesting = false } }

        #if canImport(MusicKit)
        _ = await MusicAuthorization.request()
        #endif

        await MainActor.run { refreshStatus() }
    }
}

#Preview {
    NavigationStack { MusicPermissionExplainerView() }
}
#endif

