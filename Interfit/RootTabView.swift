import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section {
                        NavigationLink {
                            QuickStartView()
                        } label: {
                            Text("Quick Start")
                        }

                        NavigationLink {
                            TrainingView()
                        } label: {
                            Text("Training")
                        }
                    }
                }
                .navigationTitle("Train")
            }
            .tabItem {
                Label("Train", systemImage: "figure.run")
            }

            NavigationStack {
                PlansListView()
            }
            .tabItem {
                Label("Plans", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                Text("Me")
                    .navigationTitle("Me")
            }
            .tabItem {
                Label("Me", systemImage: "person")
            }
        }
    }
}

#Preview {
    RootTabView()
}
