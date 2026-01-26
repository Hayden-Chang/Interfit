import SwiftUI

struct PlansListView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    PlanEditorView()
                } label: {
                    Text("Create Plan")
                }
            }
        }
        .navigationTitle("Plans")
    }
}

#Preview {
    NavigationStack {
        PlansListView()
    }
}
