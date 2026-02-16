import SwiftUI
import Shared
import Persistence

struct QuickStartView: View {
    private let onStart: ((Plan) -> Void)?

    @StateObject private var viewModel: QuickStartViewModel

    @State private var selectedPlanId: UUID?
    @State private var pendingDeletePlan: Plan?

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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") {
                                planEditorTarget = .edit(plan)
                            }
                            .tint(.blue)

                            if viewModel.canDelete(plan: plan) {
                                Button("Delete", role: .destructive) {
                                    pendingDeletePlan = plan
                                }
                            }
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
        .alert(
            "Delete plan?",
            isPresented: Binding(
                get: { pendingDeletePlan != nil },
                set: { isPresented in
                    if !isPresented { pendingDeletePlan = nil }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let pendingDeletePlan else { return }
                delete(plan: pendingDeletePlan)
                self.pendingDeletePlan = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeletePlan = nil
            }
        } message: {
            if let pendingDeletePlan {
                Text("Delete \"\(pendingDeletePlan.name)\"? This action cannot be undone.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .task {
            _ = await viewModel.reloadUserPlans()
        }
    }

    private func delete(plan: Plan) {
        Task {
            let wasSelected = selectedPlanId == plan.id
            let didDelete = await viewModel.deletePlan(id: plan.id)
            guard didDelete, wasSelected else { return }
            selectedPlanId = viewModel.availablePlans.first?.id
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
    @AppStorage("interfit.quickstart.hiddenBuiltinPlanIds") private var hiddenBuiltinPlanIdsRaw: String = ""

    private let builtinPlans: [Plan] = BuiltinPlanTemplates.quickStart
    private let repository: any PlanRepository

    init(repository: any PlanRepository = CoreDataPersistenceStore()) {
        self.repository = repository
    }

    var availablePlans: [Plan] {
        let userById = Dictionary(uniqueKeysWithValues: userPlans.map { ($0.id, $0) })
        let hiddenBuiltinPlanIds = hiddenBuiltinIds
        var merged: [Plan] = []
        merged.reserveCapacity(builtinPlans.count + userPlans.count)

        for plan in builtinPlans {
            if userById[plan.id] == nil, !hiddenBuiltinPlanIds.contains(plan.id) {
                merged.append(plan)
            }
        }
        merged.append(contentsOf: userPlans)
        return merged
    }

    @discardableResult
    func reloadUserPlans() async -> UUID? {
        userPlans = await repository.fetchAllPlans()
        return userPlans.first?.id
    }

    func canDelete(plan: Plan) -> Bool {
        availablePlans.contains(where: { $0.id == plan.id })
    }

    @discardableResult
    func deletePlan(id: UUID) async -> Bool {
        if userPlans.contains(where: { $0.id == id }) {
            await repository.deletePlan(id: id)
            userPlans = await repository.fetchAllPlans()
            return true
        }

        guard builtinPlans.contains(where: { $0.id == id }) else { return false }
        var hidden = hiddenBuiltinIds
        let inserted = hidden.insert(id).inserted
        hiddenBuiltinIds = hidden
        return inserted
    }

    private var hiddenBuiltinIds: Set<UUID> {
        get {
            Set(
                hiddenBuiltinPlanIdsRaw
                    .split(separator: ",")
                    .compactMap { UUID(uuidString: String($0)) }
            )
        }
        set {
            hiddenBuiltinPlanIdsRaw = newValue
                .map(\.uuidString)
                .sorted()
                .joined(separator: ",")
        }
    }
}
