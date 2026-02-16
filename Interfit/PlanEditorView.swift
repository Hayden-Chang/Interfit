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

    private enum DurationComponent {
        case hours
        case minutes
        case seconds
    }

    private enum DurationEditorTarget {
        case work
        case rest

        var title: String {
            switch self {
            case .work: "Work"
            case .rest: "Rest"
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
    @State private var saveErrorMessage: String?
    @State private var activeDurationEditor: DurationEditorTarget?

    @Environment(\.dismiss) private var dismiss

    private let planRepository: any PlanRepository

    init(
        plan: Plan?,
        startInModeB: Bool = false,
        planRepository: (any PlanRepository)? = nil
    ) {
        self.plan = plan
        let defaultStore = CoreDataPersistenceStore()
        self.planRepository = planRepository ?? defaultStore

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
        ZStack {
            Form {
                planSection
                timingSection
                musicSection
                sourceSection
                validationSection
                saveSection

            }
            if let target = activeDurationEditor {
                durationEditorOverlay(for: target)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeDurationEditor != nil)
        .navigationTitle(plan == nil ? "Create Plan" : "Edit Plan")
        .onChange(of: setsCount) { newValue in
            syncPerSetMusicArray(setsCount: newValue)
        }
        .onChange(of: name) { _ in
            saveErrorMessage = nil
        }
        .alert("Save failed", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
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
            durationInputs(
                editorTarget: .work,
                title: "Work",
                seconds: $workSeconds,
                range: PlanValidationAdapter.workSecondsRange
            )
            durationInputs(
                editorTarget: .rest,
                title: "Rest",
                seconds: $restSeconds,
                range: PlanValidationAdapter.restSecondsRange
            )
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
            durationInputs(
                editorTarget: .work,
                title: "Work",
                seconds: $workSeconds,
                range: PlanValidationAdapter.workSecondsRange
            )
            durationInputs(
                editorTarget: .rest,
                title: "Rest",
                seconds: $restSeconds,
                range: PlanValidationAdapter.restSecondsRange
            )
        }
    }

    private func durationInputs(
        editorTarget: DurationEditorTarget,
        title: String,
        seconds: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        return LabeledContent(title) {
            Button {
                activeDurationEditor = editorTarget
            } label: {
                HStack(spacing: 4) {
                    Text(Self.formatDurationHMS(seconds: seconds.wrappedValue))
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func durationEditorOverlay(for target: DurationEditorTarget) -> some View {
        let seconds = durationSecondsBinding(for: target)
        let range = durationRange(for: target)
        return ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    activeDurationEditor = nil
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(target.title) Duration")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        activeDurationEditor = nil
                    }
                    .buttonStyle(.bordered)
                }

                Text(Self.formatDurationHMS(seconds: seconds.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    durationWheelColumn(
                        title: "h",
                        selection: durationComponentBinding(seconds: seconds, range: range, component: .hours),
                        values: 0 ... max(0, range.upperBound / 3600)
                    )
                    durationWheelColumn(
                        title: "min",
                        selection: durationComponentBinding(seconds: seconds, range: range, component: .minutes),
                        values: 0 ... 59
                    )
                    durationWheelColumn(
                        title: "s",
                        selection: durationComponentBinding(seconds: seconds, range: range, component: .seconds),
                        values: 0 ... 59
                    )
                }
                .frame(height: 150)
            }
            .padding(16)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private func durationSecondsBinding(for target: DurationEditorTarget) -> Binding<Int> {
        switch target {
        case .work: $workSeconds
        case .rest: $restSeconds
        }
    }

    private func durationRange(for target: DurationEditorTarget) -> ClosedRange<Int> {
        switch target {
        case .work: PlanValidationAdapter.workSecondsRange
        case .rest: PlanValidationAdapter.restSecondsRange
        }
    }

    private func durationWheelColumn(
        title: String,
        selection: Binding<Int>,
        values: ClosedRange<Int>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(values), id: \.self) { value in
                Text("\(value)\(title)").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func durationComponentBinding(
        seconds: Binding<Int>,
        range: ClosedRange<Int>,
        component: DurationComponent
    ) -> Binding<Int> {
        Binding(
            get: {
                let clamped = Self.clamp(seconds.wrappedValue, to: range)
                return durationComponentValue(clamped, component: component)
            },
            set: { newValue in
                let clamped = Self.clamp(seconds.wrappedValue, to: range)
                var parts = Self.durationComponents(seconds: clamped)
                switch component {
                case .hours:
                    parts.hours = min(max(0, newValue), max(0, range.upperBound / 3600))
                case .minutes:
                    parts.minutes = min(max(0, newValue), 59)
                case .seconds:
                    parts.seconds = min(max(0, newValue), 59)
                }
                let candidate = (parts.hours * 3600) + (parts.minutes * 60) + parts.seconds
                seconds.wrappedValue = Self.clamp(candidate, to: range)
            }
        )
    }

    private func durationComponentValue(_ totalSeconds: Int, component: DurationComponent) -> Int {
        let parts = Self.durationComponents(seconds: totalSeconds)
        switch component {
        case .hours:
            return parts.hours
        case .minutes:
            return parts.minutes
        case .seconds:
            return parts.seconds
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

    private func save() {
        guard canSave else { return }
        isSaving = true
        saveErrorMessage = nil
        let toSave = draftPlan
        Task {
            if !(await ensurePlanNameIsCreatable(toSave)) {
                await MainActor.run {
                    isSaving = false
                }
                return
            }
            await planRepository.upsertPlan(toSave)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }

    private func ensurePlanNameIsCreatable(_ candidate: Plan) async -> Bool {
        // This rule is only for creating a new plan.
        guard plan == nil else { return true }

        let allPlans = await planRepository.fetchAllPlans()
        let normalizedCandidate = Self.normalizedPlanName(candidate.name)
        let hasDuplicate = allPlans.contains { existing in
            existing.id != candidate.id
                && Self.normalizedPlanName(existing.name) == normalizedCandidate
        }
        guard hasDuplicate else { return true }

        await MainActor.run {
            saveErrorMessage = "计划名称已存在，请换一个名称。"
        }
        return false
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

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func durationComponents(seconds: Int) -> (hours: Int, minutes: Int, seconds: Int) {
        let total = max(0, seconds)
        return (total / 3600, (total % 3600) / 60, total % 60)
    }

    private static func formatDurationHMS(seconds: Int) -> String {
        let parts = durationComponents(seconds: seconds)
        return String(format: "%02d:%02d:%02d", parts.hours, parts.minutes, parts.seconds)
    }

    private static func formatDuration(seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private static func normalizedPlanName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
