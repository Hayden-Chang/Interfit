import SwiftUI
import Shared
import Persistence

struct PlanEditorView: View {
    private enum TimingMode: String, CaseIterable, Identifiable {
        case modeA
        case modeB

        var id: Self { self }

        var title: String {
            switch self {
            case .modeA: "Mode A"
            case .modeB: "Mode B"
            }
        }
    }

    private enum IntensityPreset: String, CaseIterable, Identifiable {
        case light
        case medium
        case hard

        var id: Self { self }

        var title: String {
            switch self {
            case .light: "Light"
            case .medium: "Medium"
            case .hard: "Hard"
            }
        }

        var ratio: (workPart: Int, restPart: Int) {
            switch self {
            case .light: (1, 2)
            case .medium: (1, 1)
            case .hard: (2, 1)
            }
        }
    }

    private enum MusicMode: String, CaseIterable, Identifiable {
        case off
        case simple
        case perSet

        var id: Self { self }

        var title: String {
            switch self {
            case .off: "Off"
            case .simple: "Simple"
            case .perSet: "Per-set"
            }
        }
    }

    let plan: Plan?

    @State private var planId: UUID
    @State private var createdAt: Date

    @State private var name: String
    @State private var setsCount: Int
    @State private var workSeconds: Int
    @State private var restSeconds: Int

    @State private var timingMode: TimingMode
    @State private var modeBTotalSeconds: Int
    @State private var modeBWorkPart: Int
    @State private var modeBRestPart: Int

    @State private var musicMode: MusicMode
    @State private var musicSimpleWork: MusicSelection?
    @State private var musicSimpleRest: MusicSelection?
    @State private var musicPerSetWork: [MusicSelection?]
    @State private var musicPerSetRest: MusicSelection?

    @State private var isSaving: Bool = false
    @State private var isPublishing: Bool = false
    @State private var publishedVersions: [PlanVersion] = []
    @State private var publishErrorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private let planRepository: any PlanRepository
    private let versionRepository: any PlanVersionRepository

    init(
        plan: Plan?,
        startInModeB: Bool = false,
        planRepository: (any PlanRepository)? = nil,
        versionRepository: (any PlanVersionRepository)? = nil
    ) {
        self.plan = plan
        let defaultStore = CoreDataPersistenceStore()
        self.planRepository = planRepository ?? defaultStore
        self.versionRepository = versionRepository ?? defaultStore

        _planId = State(initialValue: plan?.id ?? UUID())
        _createdAt = State(initialValue: plan?.createdAt ?? Date())
        _name = State(initialValue: plan?.name ?? "My Plan")
        _setsCount = State(initialValue: plan?.setsCount ?? 8)
        _workSeconds = State(initialValue: plan?.workSeconds ?? 30)
        _restSeconds = State(initialValue: plan?.restSeconds ?? 30)

        let initialSets = plan?.setsCount ?? 8
        let initialWork = plan?.workSeconds ?? 30
        let initialRest = plan?.restSeconds ?? 30
        let initialTotal = max(0, (initialSets * initialWork) + (max(0, initialSets - 1) * initialRest))
        _timingMode = State(initialValue: startInModeB ? .modeB : .modeA)
        _modeBTotalSeconds = State(initialValue: max(60, initialTotal))
        let initialRatio = Self.normalizedRatio(workSeconds: initialWork, restSeconds: initialRest, maxPart: 20)
        _modeBWorkPart = State(initialValue: initialRatio.workPart)
        _modeBRestPart = State(initialValue: initialRatio.restPart)

        let initialStrategy = plan?.musicStrategy
        let defaultPerSet = Array(repeating: nil as MusicSelection?, count: max(0, initialSets))

        if let initialStrategy, initialStrategy.workCycle.count == initialSets, initialStrategy.restCycle.count == 1 {
            _musicMode = State(initialValue: .perSet)
            _musicPerSetWork = State(initialValue: initialStrategy.workCycle.map { Optional($0) })
            _musicPerSetRest = State(initialValue: initialStrategy.restCycle.first)
            _musicSimpleWork = State(initialValue: nil)
            _musicSimpleRest = State(initialValue: nil)
        } else if let initialStrategy, initialStrategy.workCycle.count <= 1, initialStrategy.restCycle.count <= 1 {
            _musicMode = State(initialValue: .simple)
            _musicSimpleWork = State(initialValue: initialStrategy.workCycle.first)
            _musicSimpleRest = State(initialValue: initialStrategy.restCycle.first)
            _musicPerSetWork = State(initialValue: defaultPerSet)
            _musicPerSetRest = State(initialValue: nil)
        } else if initialStrategy != nil {
            _musicMode = State(initialValue: .perSet)
            var perSet = defaultPerSet
            for (idx, sel) in (initialStrategy?.workCycle ?? []).enumerated() {
                if idx < perSet.count { perSet[idx] = sel }
            }
            _musicPerSetWork = State(initialValue: perSet)
            _musicPerSetRest = State(initialValue: initialStrategy?.restCycle.first)
            _musicSimpleWork = State(initialValue: nil)
            _musicSimpleRest = State(initialValue: nil)
        } else {
            _musicMode = State(initialValue: .off)
            _musicSimpleWork = State(initialValue: nil)
            _musicSimpleRest = State(initialValue: nil)
            _musicPerSetWork = State(initialValue: defaultPerSet)
            _musicPerSetRest = State(initialValue: nil)
        }
    }

    private var draftPlan: Plan {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Plan(
            id: planId,
            setsCount: setsCount,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            name: trimmedName.isEmpty ? "Untitled" : trimmedName,
            musicStrategy: computedMusicStrategy,
            isFavorite: plan?.isFavorite ?? false,
            forkedFromVersionId: plan?.forkedFromVersionId,
            sourcePostId: plan?.sourcePostId,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    private var validationMessages: [String] {
        PlanValidationAdapter.validationMessages(for: draftPlan) + musicValidationMessages
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && PlanValidationAdapter.canStart(plan: draftPlan)
            && musicValidationMessages.isEmpty
            && !isSaving
    }

    private var computedMusicStrategy: MusicStrategy? {
        switch musicMode {
        case .off:
            return nil
        case .simple:
            return MusicStrategyFactory.simple(work: musicSimpleWork, rest: musicSimpleRest)
        case .perSet:
            let filled = musicPerSetWork.compactMap { $0 }
            if filled.count != setsCount {
                return MusicStrategyFactory.perSet(workCycle: [], rest: musicPerSetRest)
            }
            return MusicStrategyFactory.perSet(workCycle: filled, rest: musicPerSetRest)
        }
    }

    private var musicValidationMessages: [String] {
        switch musicMode {
        case .off:
            return []
        case .simple:
            var messages: [String] = []
            if musicSimpleWork == nil { messages.append("Pick a Work track (Music · Simple).") }
            if musicSimpleRest == nil { messages.append("Pick a Rest track (Music · Simple).") }
            return messages
        case .perSet:
            var messages: [String] = []
            if musicPerSetRest == nil { messages.append("Pick a Rest track (Music · Per-set).") }
            if musicPerSetWork.count != setsCount || musicPerSetWork.contains(where: { $0 == nil }) {
                messages.append("Pick a Work track for every set (Music · Per-set).")
            }
            return messages
        }
    }

    private var modeBInput: PlanModeBInput {
        PlanModeBInput(
            totalSeconds: modeBTotalSeconds,
            setsCount: setsCount,
            workPart: modeBWorkPart,
            restPart: modeBRestPart
        )
    }

    private var modeBSuggestion: PlanModeBOutput? {
        PlanModeBCalculator.compute(modeBInput)
    }

    private var selectedIntensityPreset: IntensityPreset? {
        for preset in IntensityPreset.allCases {
            let ratio = preset.ratio
            if modeBWorkPart == ratio.workPart, modeBRestPart == ratio.restPart {
                return preset
            }
        }
        return nil
    }

    var body: some View {
        Form {
            planSection
            timingSection
            musicSection
            sourceSection
            validationSection
            saveSection
            publishSection

        }
        .navigationTitle(plan == nil ? "Create Plan" : "Edit Plan")
        .onChange(of: setsCount) { newValue in
            syncPerSetMusicArray(setsCount: newValue)
        }
        .task(id: planId) {
            await loadPublishedVersions()
        }
        .alert("Publish failed", isPresented: Binding(get: { publishErrorMessage != nil }, set: { if !$0 { publishErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(publishErrorMessage ?? "")
        }
    }

    private var planSection: some View {
        Section("Plan") {
            TextField("Name", text: $name)
            Stepper("Sets: \(setsCount)", value: $setsCount, in: PlanValidationAdapter.setsCountRange)
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            Picker("Mode", selection: $timingMode) {
                ForEach(TimingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            timingFields
        }
    }

    @ViewBuilder
    private var timingFields: some View {
        switch timingMode {
        case .modeA:
            modeAFields
        case .modeB:
            modeBFields
        }
    }

    private var modeAFields: some View {
        Group {
            Stepper("Work: \(workSeconds)s", value: $workSeconds, in: PlanValidationAdapter.workSecondsRange, step: 5)
            Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: PlanValidationAdapter.restSecondsRange, step: 5)
        }
    }

    private var modeBFields: some View {
        Group {
            modeBTotalInputs
            modeBRatioInputs
            modeBIntensityPresets
            modeBSuggestionBlock
            modeBFineTune
        }
    }

    private var modeBTotalInputs: some View {
        Group {
            LabeledContent("Total") {
                Text(Self.formatDuration(seconds: modeBTotalSeconds))
                    .foregroundStyle(.secondary)
            }
            Stepper(
                value: Binding(
                    get: { modeBTotalSeconds / 60 },
                    set: { newMinutes in
                        let secondsPart = modeBTotalSeconds % 60
                        modeBTotalSeconds = max(0, (newMinutes * 60) + secondsPart)
                    }
                ),
                in: 0 ... 600,
                step: 1
            ) {
                Text("Total minutes: \(modeBTotalSeconds / 60)")
            }
            Stepper(
                value: Binding(
                    get: { modeBTotalSeconds % 60 },
                    set: { newSeconds in
                        let minutesPart = modeBTotalSeconds / 60
                        modeBTotalSeconds = max(0, (minutesPart * 60) + newSeconds)
                    }
                ),
                in: 0 ... 59,
                step: 5
            ) {
                Text("Total seconds: \(modeBTotalSeconds % 60)")
            }
        }
    }

    private var modeBRatioInputs: some View {
        Group {
            Stepper("Work part: \(modeBWorkPart)", value: $modeBWorkPart, in: 1 ... 20)
            Stepper("Rest part: \(modeBRestPart)", value: $modeBRestPart, in: 0 ... 20)
        }
    }

    private var modeBIntensityPresets: some View {
        Group {
            Text("Intensity presets")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                ForEach(IntensityPreset.allCases) { preset in
                    let isSelected = selectedIntensityPreset == preset
                    if isSelected {
                        Button(preset.title) {
                            let ratio = preset.ratio
                            modeBWorkPart = ratio.workPart
                            modeBRestPart = ratio.restPart
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(preset.title) {
                            let ratio = preset.ratio
                            modeBWorkPart = ratio.workPart
                            modeBRestPart = ratio.restPart
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var modeBSuggestionBlock: some View {
        Group {
            if let suggestion = modeBSuggestion {
                LabeledContent("Suggested") {
                    Text("Work \(suggestion.workSeconds)s / Rest \(suggestion.restSeconds)s")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Effective total") {
                    Text(Self.formatDuration(seconds: suggestion.effectiveTotalSeconds))
                        .foregroundStyle(.secondary)
                }

                Button("Use suggested") {
                    workSeconds = suggestion.workSeconds
                    restSeconds = suggestion.restSeconds
                }
                .disabled(!canUseSuggested(suggestion))

                if !canUseSuggested(suggestion) {
                    Text("Suggested values out of allowed range. Increase total or adjust ratio/sets.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else {
                Text("No suggestion for current inputs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func canUseSuggested(_ suggestion: PlanModeBOutput) -> Bool {
        PlanValidationAdapter.workSecondsRange.contains(suggestion.workSeconds)
            && PlanValidationAdapter.restSecondsRange.contains(suggestion.restSeconds)
            && PlanValidationAdapter.setsCountRange.contains(setsCount)
    }

    private var modeBFineTune: some View {
        Group {
            Divider()
            Text("Fine tune")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Stepper("Work: \(workSeconds)s", value: $workSeconds, in: PlanValidationAdapter.workSecondsRange, step: 5)
            Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: PlanValidationAdapter.restSecondsRange, step: 5)
        }
    }

    private var musicSection: some View {
        Section("Music") {
            Picker("Mode", selection: $musicMode) {
                ForEach(MusicMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch musicMode {
            case .off:
                Text("No music will be played automatically during training.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .simple:
                musicPickerRow(title: "Work", currentSelection: musicSimpleWork) { selection in
                    musicSimpleWork = selection
                }

                musicPickerRow(title: "Rest", currentSelection: musicSimpleRest) { selection in
                    musicSimpleRest = selection
                }
            case .perSet:
                musicPickerRow(title: "Rest", currentSelection: musicPerSetRest) { selection in
                    musicPerSetRest = selection
                }

                ForEach(0..<max(0, setsCount), id: \.self) { idx in
                    musicPickerRow(title: "Work · Set \(idx + 1)", currentSelection: musicPerSetWork[safe: idx] ?? nil) { selection in
                        setPerSetWorkSelection(selection, index: idx)
                    }
                }
            }

            Text("Choose music while creating the plan. Training will follow this strategy automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        if let forkedFromVersionId = plan?.forkedFromVersionId {
            Section("Source") {
                LabeledContent("Forked from version") {
                    Text(forkedFromVersionId.uuidString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if !validationMessages.isEmpty {
            Section("Validation") {
                ForEach(validationMessages, id: \.self) { message in
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button("Save") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
    }

    private var publishSection: some View {
        Section("Publish") {
            Button(isPublishing ? "Publishing…" : "Publish as new version") {
                publish()
            }
            .disabled(!canSave || isPublishing)

            Text("发布后固定（只读）。每次发布都会创建一个新版本。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !publishedVersions.isEmpty {
                NavigationLink {
                    PlanVersionsListView(planId: planId, versionRepository: versionRepository, planRepository: planRepository)
                } label: {
                    Text("View published versions (\(publishedVersions.count))")
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        let toSave = draftPlan
        Task {
            await planRepository.upsertPlan(toSave)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }

    private func loadPublishedVersions() async {
        publishedVersions = await versionRepository.fetchPlanVersions(planId: planId)
    }

    private func publish() {
        guard canSave else { return }
        isPublishing = true
        let snapshot = draftPlan
        Task {
            await planRepository.upsertPlan(snapshot)
            let existing = await versionRepository.fetchPlanVersions(planId: snapshot.id)
            let nextVersionNumber = (existing.map(\.versionNumber).max() ?? 0) + 1
            let version = PlanVersion(
                planId: snapshot.id,
                status: .published,
                versionNumber: nextVersionNumber,
                setsCount: snapshot.setsCount,
                workSeconds: snapshot.workSeconds,
                restSeconds: snapshot.restSeconds,
                name: snapshot.name,
                musicStrategy: snapshot.musicStrategy,
                publishedAt: Date()
            )
            do {
                try await versionRepository.upsertPlanVersion(version)
                await MainActor.run {
                    isPublishing = false
                }
                await loadPublishedVersions()
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishErrorMessage = String(describing: error)
                }
            }
        }
    }

    private func syncPerSetMusicArray(setsCount: Int) {
        guard setsCount >= 0 else { return }
        if musicPerSetWork.count == setsCount { return }
        if musicPerSetWork.count < setsCount {
            musicPerSetWork.append(contentsOf: Array(repeating: nil, count: setsCount - musicPerSetWork.count))
        } else {
            musicPerSetWork = Array(musicPerSetWork.prefix(setsCount))
        }
    }

    private func setPerSetWorkSelection(_ selection: MusicSelection, index: Int) {
        syncPerSetMusicArray(setsCount: setsCount)
        guard index >= 0, index < musicPerSetWork.count else { return }
        musicPerSetWork[index] = selection
    }

    private func musicPickerRow(
        title: String,
        currentSelection: MusicSelection?,
        onPick: @escaping (MusicSelection) -> Void
    ) -> some View {
        NavigationLink {
            MusicPickerView(allowedTypes: [.track, .playlist]) { selection in
                onPick(selection)
            }
        } label: {
            LabeledContent(title) {
                Text(currentSelection?.displayTitle ?? "Select")
                    .foregroundStyle(currentSelection == nil ? .secondary : .primary)
            }
        }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = a
        var y = b
        while y != 0 {
            let r = x % y
            x = y
            y = r
        }
        return abs(x)
    }

    private static func normalizedRatio(workSeconds: Int, restSeconds: Int, maxPart: Int) -> (workPart: Int, restPart: Int) {
        guard maxPart > 0 else { return (1, 1) }
        if restSeconds == 0 { return (1, 0) }

        let w = max(1, abs(workSeconds))
        let r = max(1, abs(restSeconds))
        let g = gcd(w, r)
        var a = max(1, w / max(1, g))
        var b = max(1, r / max(1, g))

        if a <= maxPart, b <= maxPart { return (a, b) }

        let div = Int(ceil(Double(max(a, b)) / Double(maxPart)))
        a = max(1, a / max(1, div))
        b = max(1, b / max(1, div))
        return (min(maxPart, a), min(maxPart, b))
    }

    private static func formatDuration(seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    NavigationStack {
        PlanEditorView(plan: nil)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
