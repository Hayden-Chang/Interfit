//
//  ModulesDemoView.swift
//  Interfit
//
//  Created by pc on 2026/1/21.
//

import SwiftUI
import Audio
import Shared

struct ModulesDemoView: View {
    @State private var hapticsEnabled: Bool = true
    @State private var soundsEnabled: Bool = true
    @State private var isRunning: Bool = false
    @State private var engine: WorkoutSessionEngine?

    private let demoTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section("Audio") {
                LabeledContent("AudioVersion") {
                    Text(AudioVersion.value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Haptics") {
                Toggle("Enable Haptics", isOn: $hapticsEnabled)
                HStack {
                    Button(isRunning ? "Running…" : "Run 1-set demo (5+3s)") {
                        startDemoSession()
                    }
                    .disabled(isRunning)
                    Spacer()
                    Circle()
                        .fill(isRunning ? .green : .secondary)
                        .frame(width: 10, height: 10)
                        .accessibilityLabel(isRunning ? "running" : "idle")
                }
                Text("Simulates a short session. Segment switches should trigger haptics on supported devices; disabling toggle silences them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Cue Sound") {
                Toggle("Enable Sounds", isOn: $soundsEnabled)
                Text("Short beeps for cues; uses a sine tone and ducks others.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Modules")
        .onReceive(demoTimer) { now in
            guard isRunning else { return }
            guard var eng = engine else { isRunning = false; return }
            let done = eng.tick(at: now)
            engine = eng
            if done || eng.session.status == .completed || eng.session.status == .ended {
                engine = nil
                isRunning = false
            }
        }
    }

    private func startDemoSession() {
        do {
            let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 3, name: "Demo")
            var sinks: [CueSink] = []
            if hapticsEnabled { sinks.append(HapticsCueSink(enabled: true)) }
            if soundsEnabled { sinks.append(AudioCueSink(enabled: true)) }
            let multiSink = MultiCueSink(sinks)

            var eng = try WorkoutSessionEngine(
                plan: plan,
                now: Date(),
                cues: multiSink
            )
            _ = eng.tick(at: Date())
            engine = eng
            isRunning = true
        } catch {
            isRunning = false
            engine = nil
        }
    }
}

// Helper: multiplex cues to multiple sinks
struct MultiCueSink: CueSink {
    let sinks: [CueSink]
    init(_ sinks: [CueSink]) { self.sinks = sinks }
    func emit(_ event: CueEventRecord) { sinks.forEach { $0.emit(event) } }
}

#Preview {
    NavigationStack {
        ModulesDemoView()
    }
}
