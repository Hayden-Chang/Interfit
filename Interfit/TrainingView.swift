import SwiftUI

struct TrainingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Training")
                .font(.title.bold())

            Text("Session screen placeholder")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Training")
    }
}

#Preview {
    NavigationStack {
        TrainingView()
    }
}
