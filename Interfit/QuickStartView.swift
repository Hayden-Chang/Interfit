import SwiftUI
import Shared

struct QuickStartView: View {
    private let templates: [Plan] = BuiltinPlanTemplates.quickStart

    @State private var selectedPlanId: UUID?
    @State private var startedPlan: Plan?
    @State private var isShowingTraining: Bool = false

    private var selectedPlan: Plan? {
        templates.first(where: { $0.id == selectedPlanId })
    }

    private var validationMessages: [String] {
        guard let selectedPlan else { return [] }
        return PlanValidationAdapter.validationMessages(for: selectedPlan)
    }

    private var canStartSelectedPlan: Bool {
        guard let selectedPlan else { return false }
        return PlanValidationAdapter.canStart(plan: selectedPlan)
    }

    var body: some View {
        List {
            Section("Step 1 · Choose a preset") {
                ForEach(templates) { plan in
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

                Button("Start") {
                    guard let selectedPlan else { return }
                    startedPlan = selectedPlan
                    isShowingTraining = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStartSelectedPlan)
            }
        }
        .navigationTitle("Quick Start")
        .navigationDestination(isPresented: $isShowingTraining) {
            TrainingView(plan: startedPlan)
        }
    }
}

#Preview {
    NavigationStack {
        QuickStartView()
    }
}
