import SwiftUI
import Shared
import Persistence

struct QuickStartView: View {
    private let onStart: ((Plan) -> Void)?

    @StateObject private var viewModel: QuickStartViewModel

    @State private var selectedPlanId: UUID?

    private enum PlanEditorTarget: Identifiable {
        case create
        case edit(Plan)

        var id: String {
            switch self {
            case .create:
                "create"
            case let .edit(plan):
                "edit:\(plan.id.uuidString)"
            }
        }
    }

    @State private var planEditorTarget: PlanEditorTarget?

    private var selectedPlan: Plan? {
        viewModel.availablePlans.first(where: { $0.id == selectedPlanId })
    }

    private var validationMessages: [String] {
        guard let selectedPlan else { return [] }
        return PlanValidationAdapter.validationMessages(for: selectedPlan)
    }

    private var canStartSelectedPlan: Bool {
        guard let selectedPlan else { return false }
        return PlanValidationAdapter.canStart(plan: selectedPlan)
    }

    init(onStart: ((Plan) -> Void)? = nil) {
        self.onStart = onStart
        _viewModel = StateObject(wrappedValue: QuickStartViewModel())
    }

    var body: some View {
        List {
            Section("Step 1 · Choose a preset") {
                if viewModel.availablePlans.isEmpty {
                    Text("No presets available.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(viewModel.availablePlans) { plan in
                        Button {
                            selectedPlanId = plan.id
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.name)
                                        .font(.headline)
                                    PlanTemplateSummaryText(plan: plan)
                                }
                                Spacer()
                                if selectedPlanId == plan.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Edit") {
                                planEditorTarget = .edit(plan)
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            Section("Step 2 · Start") {
                if let selectedPlan {
                    LabeledContent("Selected") {
                        PlanTemplateSummaryText(plan: selectedPlan)
                    }
                    if !validationMessages.isEmpty {
                        ForEach(validationMessages, id: \.self) { message in
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Text("Pick a preset to continue.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                if let selectedPlan {
                    if let onStart {
                        Button("Start") {
                            onStart(selectedPlan)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canStartSelectedPlan)
                    } else {
                        NavigationLink("Start", value: selectedPlan)
                            .buttonStyle(.borderedProminent)
                            .disabled(!canStartSelectedPlan)
                    }
                } else {
                    Button("Start") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                }
            }
        }
        .navigationTitle("Train")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    planEditorTarget = .create
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create plan")
            }
        }
        .navigationDestination(for: Plan.self) { plan in TrainingView(plan: plan) }
        .sheet(item: $planEditorTarget, onDismiss: {
            Task {
                if let mostRecentId = await viewModel.reloadUserPlans() {
                    selectedPlanId = mostRecentId
                }
            }
        }) { target in
            NavigationStack {
                switch target {
                case .create:
                    PlanEditorView(plan: nil)
                case let .edit(plan):
                    PlanEditorView(plan: plan)
                }
            }
        }
        .task {
            _ = await viewModel.reloadUserPlans()
        }
    }
}

#Preview {
    NavigationStack {
        QuickStartView()
    }
}

@MainActor
final class QuickStartViewModel: ObservableObject {
    @Published private(set) var userPlans: [Plan] = []

    private let builtinPlans: [Plan] = BuiltinPlanTemplates.quickStart
    private let repository: any PlanRepository

    init(repository: any PlanRepository = CoreDataPersistenceStore()) {
        self.repository = repository
    }

    var availablePlans: [Plan] {
        let userById = Dictionary(uniqueKeysWithValues: userPlans.map { ($0.id, $0) })
        var merged: [Plan] = []
        merged.reserveCapacity(builtinPlans.count + userPlans.count)

        for plan in builtinPlans {
            if userById[plan.id] == nil { merged.append(plan) }
        }
        merged.append(contentsOf: userPlans)
        return merged
    }

    @discardableResult
    func reloadUserPlans() async -> UUID? {
        userPlans = await repository.fetchAllPlans()
        return userPlans.first?.id
    }
}
