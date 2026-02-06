import SwiftUI
import Shared
import Persistence

struct PlanVersionsListView: View {
    let planId: UUID
    let versionRepository: any PlanVersionRepository
    let planRepository: any PlanRepository

    @State private var versions: [PlanVersion] = []
    @State private var applyMessage: String?
    @State private var selectedPlan: Plan?
    @State private var isShowingPlanEditor: Bool = false

    init(
        planId: UUID,
        versionRepository: any PlanVersionRepository = CoreDataPersistenceStore(),
        planRepository: any PlanRepository = CoreDataPersistenceStore()
    ) {
        self.planId = planId
        self.versionRepository = versionRepository
        self.planRepository = planRepository
    }

    var body: some View {
        List {
            if versions.isEmpty {
                Text("No published versions yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(versions) { v in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("v\(v.versionNumber)")
                                .font(.headline)
                            Spacer()
                            Text(v.status == .published ? "Published" : "Draft")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(v.name)
                            .font(.subheadline)
                        Text(summaryText(for: v))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Apply") {
                            apply(version: v)
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("Published Versions")
        .navigationDestination(isPresented: $isShowingPlanEditor) {
            PlanEditorView(plan: selectedPlan)
        }
        .task {
            versions = await versionRepository.fetchPlanVersions(planId: planId)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Text("发布后固定（只读）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Applied", isPresented: Binding(get: { applyMessage != nil }, set: { if !$0 { applyMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(applyMessage ?? "")
        }
    }

    private func summaryText(for v: PlanVersion) -> String {
        let total = v.estimatedTotalSeconds
        return "(work \(v.workSeconds)s + rest \(v.restSeconds)s) × \(v.setsCount) = \(total)s"
    }

    private func apply(version: PlanVersion) {
        Task {
            await MainActor.run {
                applyMessage = nil
            }

            let existingPlans = await planRepository.fetchAllPlans()
            if let existing = existingPlans.first(where: { $0.forkedFromVersionId == version.id }) {
                await MainActor.run {
                    applyMessage = "已应用过该版本，已为你打开现有计划：\(existing.name)"
                    selectedPlan = existing
                    isShowingPlanEditor = true
                }
                return
            }
            if let existing = existingPlans.first(where: { $0.contentHash == version.contentHash }) {
                await MainActor.run {
                    applyMessage = "已存在相同内容的计划，已为你打开：\(existing.name)"
                    selectedPlan = existing
                    isShowingPlanEditor = true
                }
                return
            }

            let newPlan = Plan(
                setsCount: version.setsCount,
                workSeconds: version.workSeconds,
                restSeconds: version.restSeconds,
                name: "\(version.name) (Fork)",
                forkedFromVersionId: version.id
            )
            await planRepository.upsertPlan(newPlan)
            await MainActor.run {
                applyMessage = "已复制到预设列表：\(newPlan.name)"
                selectedPlan = newPlan
                isShowingPlanEditor = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlanVersionsListView(planId: UUID())
    }
}
