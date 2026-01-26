import SwiftUI

struct PlanEditorView: View {
    @State private var setsCount: Int = 8
    @State private var workSeconds: Int = 30
    @State private var restSeconds: Int = 30

    var body: some View {
        Form {
            Section("Plan") {
                Stepper("Sets: \(setsCount)", value: $setsCount, in: 1...50)
                Stepper("Work: \(workSeconds)s", value: $workSeconds, in: 5...600, step: 5)
                Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...600, step: 5)
            }

            Section {
                Button("Save") {
                    // TODO: persistence in 1.6.4+
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Edit Plan")
    }
}

#Preview {
    NavigationStack {
        PlanEditorView()
    }
}
