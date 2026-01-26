import SwiftUI

struct QuickStartView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Quick Start")
                .font(.title.bold())

            Button("Start") {
                // TODO: wire up WorkoutSessionEngine in 1.6.2+
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Quick Start")
    }
}

#Preview {
    NavigationStack {
        QuickStartView()
    }
}
