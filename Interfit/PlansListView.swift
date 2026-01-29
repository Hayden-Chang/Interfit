import SwiftUI
import Shared
import Persistence

struct PlansListView: View {
    @StateObject private var viewModel = PlansListViewModel()

    var body: some View {
        List {
            if viewModel.plans.isEmpty {
                Section {
                    Text("No plans yet")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Your Plans") {
                    ForEach(viewModel.plans) { plan in
                        NavigationLink {
                            PlanEditorView(plan: plan)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                    .font(.headline)
                                PlanTemplateSummaryText(plan: plan)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        Task { await viewModel.delete(at: idx) }
                    }
                }
            }
        }
        .navigationTitle("Plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PlanEditorView(plan: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        PlansListView()
    }
}

@MainActor
final class PlansListViewModel: ObservableObject {
    @Published var plans: [Plan] = []

    private let repository: any PlanRepository

    init(repository: any PlanRepository = CoreDataPersistenceStore()) {
        self.repository = repository
    }

    func load() async {
        plans = await repository.fetchAllPlans()
    }

    func delete(at offsets: IndexSet) async {
        let ids = offsets.compactMap { plans[safe: $0]?.id }
        for id in ids { await repository.deletePlan(id: id) }
        await load()
    }
}

private extension Array {
    subscript(safe idx: Int) -> Element? {
        guard indices.contains(idx) else { return nil }
        return self[idx]
    }
}
