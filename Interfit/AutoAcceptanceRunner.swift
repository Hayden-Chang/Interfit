#if DEBUG
import Foundation
import Persistence
import Shared
import Audio
import MediaPlayer

enum AutoAcceptanceRunner {
    static func runIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) async {
        if arguments.contains("-debugSeedRecoverableSnapshot_3_2_4_1") {
            await debugSeedRecoverableSnapshot_3_2_4_1()
        }

        if arguments.contains("-autoAcceptance_3_2_1_1") {
            await run_3_2_1_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_2_2_1") {
            await run_3_2_2_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_2_3_1") {
            await run_3_2_3_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_3_2_1") {
            await run_3_3_2_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_3_3_1") {
            await run_3_3_3_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_1_3_1") {
            await run_3_1_3_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_5_1_1") {
            await run_3_5_1_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_5_2_1") {
            await run_3_5_2_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_6_2_1") {
            await run_3_6_2_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_7_1_1") {
            await run_3_7_1_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_7_2_1") {
            await run_3_7_2_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_4_2_1") {
            await run_3_4_2_1(arguments: arguments)
        }

        if arguments.contains("-autoAcceptance_3_4_1_1") {
            await run_3_4_1_1(arguments: arguments)
        }
    }

    private static func debugSeedRecoverableSnapshot_3_2_4_1() async {
        let store = CoreDataPersistenceStore()
        await store.resetAllData()

        let plan = Plan(setsCount: 3, workSeconds: 10, restSeconds: 5, name: "Debug Seed Recoverable Snapshot")
        let start = Date(timeIntervalSince1970: 0)
        guard var engine = try? WorkoutSessionEngine(plan: plan, now: start, cues: NoopCueSink(), playback: NoopPlaybackIntentSink()) else {
            return
        }
        _ = engine.tick(at: start.addingTimeInterval(7))
        let snapshot = engine.recoverableSnapshot(at: start.addingTimeInterval(7))
        await store.upsertRecoverableSessionSnapshot(snapshot)

        let report = DebugSeedRecoverableSnapshotReport(
            name: "3.2.4.1",
            createdAt: Date(),
            elapsedSeconds: snapshot.elapsedSeconds,
            sessionId: snapshot.session.id
        )
        await report.persist(filename: "debug_seed_recoverable_snapshot_3_2_4_1.json")
    }

    private static func run_3_3_2_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_3_2_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let store = CoreDataPersistenceStore()
        await store.resetAllData()

        let simulatePlaybackLoadFailure = arguments.contains("-simulatePlaybackLoadFailure")
        let report = await AutoAcceptance_3_3_2_1.run(store: store, simulatePlaybackLoadFailure: simulatePlaybackLoadFailure)
        await report.persist(filename: "auto_acceptance_3_3_2_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_2_1_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_2_1_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = await AutoAcceptance_3_2_1_1.run()
        await report.persist(filename: "auto_acceptance_3_2_1_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_2_2_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_2_2_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let store = CoreDataPersistenceStore()
        await store.resetAllData()

        let report = await AutoAcceptance_3_2_2_1.run(store: store)
        await report.persist(filename: "auto_acceptance_3_2_2_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_2_3_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_2_3_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = AutoAcceptance_3_2_3_1.run()
        await report.persist(filename: "auto_acceptance_3_2_3_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_3_3_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_3_3_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let store = CoreDataPersistenceStore()
        await store.resetAllData()

        let report = await AutoAcceptance_3_3_3_1.run(store: store)
        await report.persist(filename: "auto_acceptance_3_3_3_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_1_3_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_1_3_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = AutoAcceptance_3_1_3_1.run()
        await report.persist(filename: "auto_acceptance_3_1_3_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_5_1_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_5_1_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = AutoAcceptance_3_5_1_1.run()
        await report.persist(filename: "auto_acceptance_3_5_1_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_5_2_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_5_2_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = AutoAcceptance_3_5_2_1.run()
        await report.persist(filename: "auto_acceptance_3_5_2_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_6_2_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_6_2_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = await AutoAcceptance_3_6_2_1.run()
        await report.persist(filename: "auto_acceptance_3_6_2_1.json")

        defaults.set(true, forKey: seededKey)
    }

    @MainActor
    private static func run_3_7_1_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_7_1_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = AutoAcceptance_3_7_1_1.run()
        await report.persist(filename: "auto_acceptance_3_7_1_1.json")

        defaults.set(true, forKey: seededKey)
    }

    @MainActor
    private static func run_3_7_2_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_7_2_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let report = AutoAcceptance_3_7_2_1.run()
        await report.persist(filename: "auto_acceptance_3_7_2_1.json")

        defaults.set(true, forKey: seededKey)
    }

    private static func run_3_4_2_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_4_2_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        let store = CoreDataPersistenceStore()
        await store.resetAllData()

        let report = await AutoAcceptance_3_4_2_1.run(store: store)
        await report.persist(filename: "auto_acceptance_3_4_2_1.json")

        defaults.set(true, forKey: seededKey)
    }

    @MainActor
    private static func run_3_4_1_1(arguments: [String]) async {
        let defaults = UserDefaults.standard
        let seededKey = "interfit.autoAcceptance.3_4_1_1.completed"
        guard !defaults.bool(forKey: seededKey) else { return }

        defaults.set(true, forKey: "interfit.backup.icloudEnabled")
        let service = ICloudBackupService()
        await service.runBackupIfEnabled()

        let report = AutoAcceptance_3_4_1_1.Report(
            name: "3.4.1.1",
            passed: service.lastStatus != nil,
            createdAt: Date(),
            status: AutoAcceptance_3_4_1_1.statusString(service.lastStatus),
            failures: service.lastStatus == nil ? ["Expected lastStatus to be set."] : []
        )
        await report.persist(filename: "auto_acceptance_3_4_1_1.json")

        defaults.set(true, forKey: seededKey)
    }
}

private enum AutoAcceptance_3_2_1_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var didReturnNilSnapshot: Bool
        var didClearCorruptedPayload: Bool
        var didWriteDecodeFailedAtMarker: Bool
        var didWriteDecodeFailedBytesMarker: Bool
        var decodeFailedBytesValue: Int?
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() async -> Report {
        var failures: [String] = []

        let snapshotKey = "interfit.persistence.recoverableSessionSnapshot"
        let decodeFailedAtKey = "interfit.persistence.recoverableSessionSnapshot.decodeFailedAt"
        let decodeFailedBytesKey = "interfit.persistence.recoverableSessionSnapshot.decodeFailedBytes"

        let store = CoreDataPersistenceStore()
        await store.resetAllData()

        let corrupted = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00])
        UserDefaults.standard.set(corrupted, forKey: snapshotKey)

        let fetched = await store.fetchRecoverableSessionSnapshot()
        let didReturnNilSnapshot = fetched == nil
        if !didReturnNilSnapshot {
            failures.append("Expected fetchRecoverableSessionSnapshot() to return nil for corrupted payload.")
        }

        let didClearCorruptedPayload = UserDefaults.standard.data(forKey: snapshotKey) == nil
        if !didClearCorruptedPayload {
            failures.append("Expected corrupted recoverable snapshot payload to be cleared.")
        }

        let didWriteDecodeFailedAtMarker = (UserDefaults.standard.object(forKey: decodeFailedAtKey) as? Date) != nil
        if !didWriteDecodeFailedAtMarker {
            failures.append("Expected decodeFailedAt marker to be written.")
        }

        let bytesValue = UserDefaults.standard.object(forKey: decodeFailedBytesKey) as? Int
        let didWriteDecodeFailedBytesMarker = bytesValue != nil
        if !didWriteDecodeFailedBytesMarker {
            failures.append("Expected decodeFailedBytes marker to be written.")
        } else if bytesValue != corrupted.count {
            failures.append("Expected decodeFailedBytes=\(corrupted.count), got \(bytesValue ?? -1).")
        }

        return Report(
            name: "3.2.1.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            didReturnNilSnapshot: didReturnNilSnapshot,
            didClearCorruptedPayload: didClearCorruptedPayload,
            didWriteDecodeFailedAtMarker: didWriteDecodeFailedAtMarker,
            didWriteDecodeFailedBytesMarker: didWriteDecodeFailedBytesMarker,
            decodeFailedBytesValue: bytesValue,
            failures: failures
        )
    }
}

private enum AutoAcceptance_3_5_1_1 {
    struct CaseReport: Codable, Sendable, Equatable {
        var name: String
        var inputTotalSeconds: Int
        var inputSetsCount: Int
        var inputWorkPart: Int
        var inputRestPart: Int

        var outputWorkSeconds: Int?
        var outputRestSeconds: Int?
        var outputEffectiveTotalSeconds: Int?
        var isSuggestedPlanValid: Bool
        var failures: [String]
    }

    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var cases: [CaseReport]
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() -> Report {
        var failures: [String] = []
        var caseReports: [CaseReport] = []

        func runCase(_ name: String, input: PlanModeBInput, expectValid: Bool) {
            var localFailures: [String] = []

            let output = PlanModeBCalculator.compute(input)
            if output == nil { localFailures.append("Expected non-nil output for valid inputs.") }

            var isSuggestedPlanValid = false
            var outputWorkSeconds: Int?
            var outputRestSeconds: Int?
            var outputEffectiveTotalSeconds: Int?
            if let output {
                outputWorkSeconds = output.workSeconds
                outputRestSeconds = output.restSeconds
                outputEffectiveTotalSeconds = output.effectiveTotalSeconds

                let computedTotal = (input.setsCount * output.workSeconds) + (max(0, input.setsCount - 1) * output.restSeconds)
                if computedTotal != output.effectiveTotalSeconds {
                    localFailures.append("effectiveTotalSeconds mismatch: expected \(computedTotal), got \(output.effectiveTotalSeconds).")
                }
                if output.effectiveTotalSeconds > input.totalSeconds {
                    localFailures.append("effectiveTotalSeconds should be <= totalSeconds (\(input.totalSeconds)), got \(output.effectiveTotalSeconds).")
                }

                let suggested = Plan(
                    setsCount: input.setsCount,
                    workSeconds: output.workSeconds,
                    restSeconds: output.restSeconds,
                    name: "Auto Acceptance 3.5.1.1"
                )
                isSuggestedPlanValid = PlanValidationAdapter.canStart(plan: suggested)
            }

            if expectValid, !isSuggestedPlanValid {
                localFailures.append("Expected suggested plan to be valid, but it was invalid.")
            }
            if !expectValid, isSuggestedPlanValid {
                localFailures.append("Expected suggested plan to be invalid, but it was valid.")
            }

            caseReports.append(
                CaseReport(
                    name: name,
                    inputTotalSeconds: input.totalSeconds,
                    inputSetsCount: input.setsCount,
                    inputWorkPart: input.workPart,
                    inputRestPart: input.restPart,
                    outputWorkSeconds: outputWorkSeconds,
                    outputRestSeconds: outputRestSeconds,
                    outputEffectiveTotalSeconds: outputEffectiveTotalSeconds,
                    isSuggestedPlanValid: isSuggestedPlanValid,
                    failures: localFailures
                )
            )
            failures.append(contentsOf: localFailures.map { "[\(name)] \($0)" })
        }

        runCase(
            "balanced_10min_10sets_1to1",
            input: PlanModeBInput(totalSeconds: 600, setsCount: 10, workPart: 1, restPart: 1),
            expectValid: true
        )
        runCase(
            "work_heavy_10min_10sets_2to1",
            input: PlanModeBInput(totalSeconds: 600, setsCount: 10, workPart: 2, restPart: 1),
            expectValid: true
        )
        runCase(
            "no_rest_3min_6sets_1to0",
            input: PlanModeBInput(totalSeconds: 180, setsCount: 6, workPart: 1, restPart: 0),
            expectValid: true
        )
        runCase(
            "too_short_should_be_invalid",
            input: PlanModeBInput(totalSeconds: 30, setsCount: 10, workPart: 1, restPart: 1),
            expectValid: false
        )

        return Report(
            name: "3.5.1.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            cases: caseReports,
            failures: failures
        )
    }
}

private enum AutoAcceptance_3_1_3_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var pausedReason: String?
        var interruptionReason: String?
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() -> Report {
        var failures: [String] = []
        let start = Date(timeIntervalSince1970: 0)
        let plan = Plan(setsCount: 2, workSeconds: 30, restSeconds: 10, name: "Auto Acceptance 3.1.3.1")

        var engine: WorkoutSessionEngine
        do {
            engine = try WorkoutSessionEngine(plan: plan, now: start, cues: NoopCueSink(), playback: NoopPlaybackIntentSink())
        } catch {
            return Report(
                name: "3.1.3.1",
                passed: false,
                createdAt: Date(),
                pausedReason: nil,
                interruptionReason: nil,
                failures: ["Engine init failed: \(String(describing: error))"]
            )
        }

        engine.handleInterruption(.init(kind: .routeChanged, attributes: ["reason": "oldDeviceUnavailable"]))

        if engine.session.status != .paused {
            failures.append("Expected session status to be paused, got \(engine.session.status).")
        }

        let pausedReason = engine.session.events.last(where: { $0.kind == .paused })?.attributes["reason"]
        if pausedReason != PauseReason.safety.rawValue {
            failures.append("Expected paused reason safety, got \(pausedReason ?? "nil").")
        }

        let interruptionReason = engine.session.events.last(where: { $0.name == "interruption" })?.attributes["reason"]
        if interruptionReason != "oldDeviceUnavailable" {
            failures.append("Expected interruption reason oldDeviceUnavailable, got \(interruptionReason ?? "nil").")
        }

        return Report(
            name: "3.1.3.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            pausedReason: pausedReason,
            interruptionReason: interruptionReason,
            failures: failures
        )
    }
}

private enum AutoAcceptance_3_5_2_1 {
    struct PresetReport: Codable, Sendable, Equatable {
        var name: String
        var workPart: Int
        var restPart: Int
        var suggestedWorkSeconds: Int?
        var suggestedRestSeconds: Int?
        var isSuggestedPlanValid: Bool
        var failures: [String]
    }

    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var presets: [PresetReport]
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() -> Report {
        let inputTotalSeconds = 600
        let inputSetsCount = 10

        let presets: [(name: String, workPart: Int, restPart: Int)] = [
            ("Light", 1, 2),
            ("Medium", 1, 1),
            ("Hard", 2, 1),
        ]

        var failures: [String] = []
        var reports: [PresetReport] = []

        for preset in presets {
            var localFailures: [String] = []
            let input = PlanModeBInput(
                totalSeconds: inputTotalSeconds,
                setsCount: inputSetsCount,
                workPart: preset.workPart,
                restPart: preset.restPart
            )
            let output = PlanModeBCalculator.compute(input)
            if output == nil { localFailures.append("Expected non-nil suggestion output.") }

            var isSuggestedPlanValid = false
            if let output {
                let suggested = Plan(
                    setsCount: input.setsCount,
                    workSeconds: output.workSeconds,
                    restSeconds: output.restSeconds,
                    name: "Auto Acceptance 3.5.2.1"
                )
                isSuggestedPlanValid = PlanValidationAdapter.canStart(plan: suggested)
                if !isSuggestedPlanValid {
                    localFailures.append("Expected suggested plan to be valid for preset \(preset.name).")
                }
            }

            reports.append(
                PresetReport(
                    name: preset.name,
                    workPart: preset.workPart,
                    restPart: preset.restPart,
                    suggestedWorkSeconds: output?.workSeconds,
                    suggestedRestSeconds: output?.restSeconds,
                    isSuggestedPlanValid: isSuggestedPlanValid,
                    failures: localFailures
                )
            )
            failures.append(contentsOf: localFailures.map { "[\(preset.name)] \($0)" })
        }

        // Sanity: expect at least 2 unique suggestions across presets.
        let uniquePairs: Set<String> = Set(reports.compactMap { report in
            guard let work = report.suggestedWorkSeconds, let rest = report.suggestedRestSeconds else { return nil }
            return "\(work)-\(rest)"
        })
        if uniquePairs.count < 2 {
            failures.append("Expected presets to produce at least 2 distinct (work,rest) suggestions.")
        }

        return Report(
            name: "3.5.2.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            presets: reports,
            failures: failures
        )
    }
}

private enum AutoAcceptance_3_6_2_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var analyticsFileExistsWhenOptedOut: Bool
        var analyticsFileExistsWhenOptedIn: Bool
        var analyticsFileContainsDisallowedKeys: Bool
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() async -> Report {
        var failures: [String] = []
        let defaults = UserDefaults.standard

        let appSupportDir: URL
        do {
            appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            return Report(
                name: "3.6.2.1",
                passed: false,
                createdAt: Date(),
                analyticsFileExistsWhenOptedOut: false,
                analyticsFileExistsWhenOptedIn: false,
                analyticsFileContainsDisallowedKeys: false,
                failures: ["Failed to resolve applicationSupportDirectory: \(String(describing: error))"]
            )
        }

        let analyticsURL = appSupportDir.appendingPathComponent(AnalyticsEventRecorder.fileName)
        try? FileManager.default.removeItem(at: analyticsURL)

        // Case A: opt-out => should not create analytics file.
        defaults.set(false, forKey: AnalyticsEventRecorder.optInKey)
        await AnalyticsEventRecorder.shared.record(
            name: "test.privacy",
            properties: [
                "kind": "music",
                "song_title": "SHOULD_NOT_BE_COLLECTED",
                "comment_text": "SHOULD_NOT_BE_COLLECTED",
            ]
        )
        let existsWhenOptedOut = FileManager.default.fileExists(atPath: analyticsURL.path)
        if existsWhenOptedOut {
            failures.append("Expected analytics file to NOT exist when opted out.")
        }

        // Case B: opt-in => file exists and contains no disallowed keys.
        defaults.set(true, forKey: AnalyticsEventRecorder.optInKey)
        await AnalyticsEventRecorder.shared.record(
            name: "test.privacy",
            properties: [
                "kind": "music",
                "song_title": "SHOULD_NOT_BE_COLLECTED",
                "comment_text": "SHOULD_NOT_BE_COLLECTED",
            ]
        )
        let existsWhenOptedIn = FileManager.default.fileExists(atPath: analyticsURL.path)
        if !existsWhenOptedIn {
            failures.append("Expected analytics file to exist when opted in.")
        }

        var containsDisallowedKeys = false
        if existsWhenOptedIn, let data = try? Data(contentsOf: analyticsURL), let text = String(data: data, encoding: .utf8) {
            if text.contains("song_title") || text.contains("comment_text") {
                containsDisallowedKeys = true
                failures.append("Analytics file contains disallowed keys (song_title/comment_text).")
            }
            if !text.contains("\"kind\"") {
                failures.append("Expected analytics event to retain allowed key: kind.")
            }
        }

        // Restore default to avoid surprising subsequent runs.
        defaults.set(true, forKey: AnalyticsEventRecorder.optInKey)

        return Report(
            name: "3.6.2.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            analyticsFileExistsWhenOptedOut: existsWhenOptedOut,
            analyticsFileExistsWhenOptedIn: existsWhenOptedIn,
            analyticsFileContainsDisallowedKeys: containsDisallowedKeys,
            failures: failures
        )
    }
}

@MainActor
private enum AutoAcceptance_3_7_1_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var hasNowPlayingInfoWhenRunning: Bool
        var hasNowPlayingInfoWhenPaused: Bool
        var nowPlayingClearedAfterStop: Bool
        var playbackRateRunning: Double?
        var playbackRatePaused: Double?
        var elapsedSeconds: Double?
        var durationSeconds: Double?
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() -> Report {
        var failures: [String] = []

        let manager = NowPlayingManager()
        manager.start()

        let structure = WorkoutStructure(setsCount: 2, workSeconds: 30, restSeconds: 10)
        let progress = structure.progress(atElapsedSeconds: 5)
        manager.update(planName: "Auto Acceptance 3.7.1.1", progress: progress, sessionStatus: .running)

        let runningInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let hasRunning = runningInfo != nil
        if !hasRunning { failures.append("Expected nowPlayingInfo to be set while running.") }

        let rateRunning = runningInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double
        let elapsed = runningInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
        let duration = runningInfo?[MPMediaItemPropertyPlaybackDuration] as? Double

        if rateRunning != 1.0 { failures.append("Expected playbackRate=1.0 while running, got \(rateRunning.map(String.init(describing:)) ?? "nil").") }
        if elapsed != 5.0 { failures.append("Expected elapsedPlaybackTime=5, got \(elapsed.map(String.init(describing:)) ?? "nil").") }
        if duration != 30.0 { failures.append("Expected playbackDuration=30, got \(duration.map(String.init(describing:)) ?? "nil").") }

        manager.update(planName: "Auto Acceptance 3.7.1.1", progress: progress, sessionStatus: .paused)
        let pausedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let hasPaused = pausedInfo != nil
        if !hasPaused { failures.append("Expected nowPlayingInfo to remain set while paused.") }
        let ratePaused = pausedInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double
        if ratePaused != 0.0 { failures.append("Expected playbackRate=0.0 while paused, got \(ratePaused.map(String.init(describing:)) ?? "nil").") }

        manager.stop()
        let cleared = (MPNowPlayingInfoCenter.default().nowPlayingInfo == nil)
        if !cleared { failures.append("Expected nowPlayingInfo to be cleared after stop().") }

        return Report(
            name: "3.7.1.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            hasNowPlayingInfoWhenRunning: hasRunning,
            hasNowPlayingInfoWhenPaused: hasPaused,
            nowPlayingClearedAfterStop: cleared,
            playbackRateRunning: rateRunning,
            playbackRatePaused: ratePaused,
            elapsedSeconds: elapsed,
            durationSeconds: duration,
            failures: failures
        )
    }
}

@MainActor
private enum AutoAcceptance_3_7_2_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var shouldShowWhenNotShown: Bool
        var shouldShowWhenAlreadyShown: Bool
        var shouldShowWhenRecovering: Bool
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() -> Report {
        var failures: [String] = []

        let shouldShowWhenNotShown = BackgroundTimingNoticePolicy.shouldShow(hasShown: false, isRecovering: false)
        if !shouldShowWhenNotShown { failures.append("Expected notice to show when not shown yet and not recovering.") }

        let shouldShowWhenAlreadyShown = BackgroundTimingNoticePolicy.shouldShow(hasShown: true, isRecovering: false)
        if shouldShowWhenAlreadyShown { failures.append("Expected notice to NOT show when already shown.") }

        let shouldShowWhenRecovering = BackgroundTimingNoticePolicy.shouldShow(hasShown: false, isRecovering: true)
        if shouldShowWhenRecovering { failures.append("Expected notice to NOT show on recovery path.") }

        return Report(
            name: "3.7.2.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            shouldShowWhenNotShown: shouldShowWhenNotShown,
            shouldShowWhenAlreadyShown: shouldShowWhenAlreadyShown,
            shouldShowWhenRecovering: shouldShowWhenRecovering,
            failures: failures
        )
    }
}

private struct DebugSeedRecoverableSnapshotReport: Codable, Sendable {
    var name: String
    var createdAt: Date
    var elapsedSeconds: Int
    var sessionId: UUID

    func persist(filename: String) async {
        do {
            let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(filename)
            let data = try JSONEncoder.prettyISO8601.encode(self)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
        }
    }
}

@MainActor
private final class AutoAcceptance_3_2_2_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var continuePathPassed: Bool
        var endAndSavePathPassed: Bool
        var discardPathPassed: Bool
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    private let store: CoreDataPersistenceStore

    private init(store: CoreDataPersistenceStore) {
        self.store = store
    }

    static func run(store: CoreDataPersistenceStore) async -> Report {
        let runner = AutoAcceptance_3_2_2_1(store: store)
        return await runner.run()
    }

    private func run() async -> Report {
        var failures: [String] = []

        let continuePassed = await runContinuePath(failures: &failures)
        let endAndSavePassed = await runEndAndSavePath(failures: &failures)
        let discardPassed = await runDiscardPath(failures: &failures)

        return Report(
            name: "3.2.2.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            continuePathPassed: continuePassed,
            endAndSavePathPassed: endAndSavePassed,
            discardPathPassed: discardPassed,
            failures: failures
        )
    }

    private func seedRecoverableSnapshot() async -> RecoverableSessionSnapshot? {
        await store.resetAllData()
        let plan = Plan(setsCount: 3, workSeconds: 10, restSeconds: 5, name: "Auto Acceptance 3.2.2.1")
        let start = Date(timeIntervalSince1970: 0)
        guard var engine = try? WorkoutSessionEngine(plan: plan, now: start, cues: NoopCueSink(), playback: NoopPlaybackIntentSink()) else {
            return nil
        }
        _ = engine.tick(at: start.addingTimeInterval(7))
        let snapshot = engine.recoverableSnapshot(at: start.addingTimeInterval(7))
        await store.upsertRecoverableSessionSnapshot(snapshot)
        return snapshot
    }

    private func runContinuePath(failures: inout [String]) async -> Bool {
        guard let seeded = await seedRecoverableSnapshot() else {
            failures.append("[continue] Failed to seed recoverable snapshot.")
            return false
        }

        guard let fetched = await store.fetchRecoverableSessionSnapshot() else {
            failures.append("[continue] Expected fetchRecoverableSessionSnapshot to return a snapshot.")
            return false
        }

        if fetched.elapsedSeconds != seeded.elapsedSeconds {
            failures.append("[continue] Seeded/fetched elapsedSeconds mismatch.")
            return false
        }

        let recovered: WorkoutSessionEngine?
        do {
            recovered = try WorkoutSessionEngine(recovering: fetched, now: Date(), cues: NoopCueSink(), playback: NoopPlaybackIntentSink())
        } catch {
            failures.append("[continue] Recovery init failed: \(String(describing: error))")
            return false
        }

        guard let recovered else { return false }
        if recovered.session.status != .paused {
            failures.append("[continue] Expected recovered session to be paused.")
            return false
        }

        return true
    }

    private func runEndAndSavePath(failures: inout [String]) async -> Bool {
        guard let fetched = await seedRecoverableSnapshot() else {
            failures.append("[end_save] Failed to seed recoverable snapshot.")
            return false
        }

        guard var engine = try? WorkoutSessionEngine(recovering: fetched, now: Date(), cues: NoopCueSink(), playback: NoopPlaybackIntentSink()) else {
            failures.append("[end_save] Recovery init failed.")
            return false
        }

        let now = Date()
        _ = try? engine.end(at: now, confirmed: true)
        await store.upsertSession(engine.session)
        await store.clearRecoverableSessionSnapshot()

        let sessions = await store.fetchAllSessions()
        if sessions.isEmpty {
            failures.append("[end_save] Expected at least one session saved.")
            return false
        }
        if await store.fetchRecoverableSessionSnapshot() != nil {
            failures.append("[end_save] Expected recoverable snapshot to be cleared.")
            return false
        }
        return true
    }

    private func runDiscardPath(failures: inout [String]) async -> Bool {
        guard let _ = await seedRecoverableSnapshot() else {
            failures.append("[discard] Failed to seed recoverable snapshot.")
            return false
        }

        await store.clearRecoverableSessionSnapshot()
        let remaining = await store.fetchRecoverableSessionSnapshot()
        if remaining != nil {
            failures.append("[discard] Expected recoverable snapshot to be cleared.")
            return false
        }

        let sessions = await store.fetchAllSessions()
        if !sessions.isEmpty {
            failures.append("[discard] Expected no sessions to be saved on discard.")
            return false
        }
        return true
    }
}

private enum AutoAcceptance_3_2_3_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var eventsCountBeforeTick: Int
        var eventsCountAfterTick: Int
        var segmentKindAfterTick: String?
        var completedSets: Int
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func run() -> Report {
        var failures: [String] = []
        let t0 = Date(timeIntervalSince1970: 0)
        let snapshotSession = Session(
            status: .paused,
            startedAt: t0,
            endedAt: nil,
            planSnapshot: PlanSnapshot(planId: nil, setsCount: 2, workSeconds: 10, restSeconds: 10, name: "Test", capturedAt: t0),
            completedSets: 0,
            totalSets: 2,
            workSeconds: 10,
            restSeconds: 10,
            events: []
        )
        let snapshot = RecoverableSessionSnapshot(session: snapshotSession, elapsedSeconds: 10, capturedAt: Date(timeIntervalSince1970: 10))

        let recovered: WorkoutSessionEngine
        do {
            recovered = try WorkoutSessionEngine(recovering: snapshot, now: Date(timeIntervalSince1970: 100), cues: NoopCueSink(), playback: NoopPlaybackIntentSink())
        } catch {
            return Report(
                name: "3.2.3.1",
                passed: false,
                createdAt: Date(),
                eventsCountBeforeTick: 0,
                eventsCountAfterTick: 0,
                segmentKindAfterTick: nil,
                completedSets: 0,
                failures: ["Recovery init failed: \(String(describing: error))"]
            )
        }

        var engine = recovered
        let before = engine.session.events.count
        _ = engine.tick(at: Date(timeIntervalSince1970: 100))
        let after = engine.session.events.count

        if after != before {
            failures.append("Expected no events to be added on first tick at boundary; before=\(before), after=\(after).")
        }

        let kind = engine.progress(at: Date(timeIntervalSince1970: 100)).currentSegment?.kind
        if kind != .rest {
            failures.append("Expected current segment to be rest after recovery boundary, got \(String(describing: kind)).")
        }
        if engine.session.completedSets != 1 {
            failures.append("Expected completedSets=1, got \(engine.session.completedSets).")
        }

        return Report(
            name: "3.2.3.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            eventsCountBeforeTick: before,
            eventsCountAfterTick: after,
            segmentKindAfterTick: kind?.rawValue,
            completedSets: engine.session.completedSets,
            failures: failures
        )
    }
}

@MainActor
private final class AutoAcceptance_3_3_2_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var plan: Plan
        var sessionId: UUID
        var segmentChangedCount: Int
        var hasSegmentChangeToSecondSet: Bool
        var degradedEventLabel: String?
        var degradedAttributes: [String: String]?
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                // Best-effort: do not crash the app in debug automation.
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    private let store: CoreDataPersistenceStore
    private let simulatePlaybackLoadFailure: Bool

    private var engine: WorkoutSessionEngine?

    private init(store: CoreDataPersistenceStore, simulatePlaybackLoadFailure: Bool) {
        self.store = store
        self.simulatePlaybackLoadFailure = simulatePlaybackLoadFailure
    }

    static func run(store: CoreDataPersistenceStore, simulatePlaybackLoadFailure: Bool) async -> Report {
        let runner = AutoAcceptance_3_3_2_1(store: store, simulatePlaybackLoadFailure: simulatePlaybackLoadFailure)
        return await runner.run()
    }

    private func run() async -> Report {
        let start = Date(timeIntervalSince1970: 0)
        let plan = Plan(setsCount: 2, workSeconds: 1, restSeconds: 0, name: "Auto Acceptance 3.3.2.1")

        let playback = makePlaybackCoordinator()
        do {
            engine = try WorkoutSessionEngine(plan: plan, now: start, cues: NoopCueSink(), playback: playback)
        } catch {
            return Report(
                name: "3.3.2.1",
                passed: false,
                createdAt: Date(),
                plan: plan,
                sessionId: UUID(),
                segmentChangedCount: 0,
                hasSegmentChangeToSecondSet: false,
                degradedEventLabel: nil,
                degradedAttributes: nil,
                failures: ["Engine init failed: \(String(describing: error))"]
            )
        }

        // Allow retry+fallback tasks to complete (policy delay is ~0.5s total).
        try? await Task.sleep(nanoseconds: 900_000_000)

        tickIfNeeded(at: start.addingTimeInterval(1))
        tickIfNeeded(at: start.addingTimeInterval(2))
        tickIfNeeded(at: start.addingTimeInterval(3))

        guard let finalSession = engine?.session else {
            return Report(
                name: "3.3.2.1",
                passed: false,
                createdAt: Date(),
                plan: plan,
                sessionId: UUID(),
                segmentChangedCount: 0,
                hasSegmentChangeToSecondSet: false,
                degradedEventLabel: nil,
                degradedAttributes: nil,
                failures: ["Engine missing final session."]
            )
        }

        await store.upsertSession(finalSession)

        var failures: [String] = []

        let segmentChanged = finalSession.events.filter { $0.name == "segmentChanged" }
        let segmentChangedCount = segmentChanged.count
        if segmentChangedCount < 2 {
            failures.append("Expected >=2 segmentChanged events, got \(segmentChangedCount).")
        }
        let hasSegmentChangeToSecondSet = segmentChanged.contains { $0.attributes["to"] == "work#2" }
        if !hasSegmentChangeToSecondSet {
            failures.append("Expected a segmentChanged event to work#2.")
        }

        let degraded = finalSession.events.last(where: { $0.name == "degraded" })
        if simulatePlaybackLoadFailure {
            if degraded == nil {
                failures.append("Expected a degraded event when -simulatePlaybackLoadFailure is enabled.")
            } else {
                if degraded?.attributes["reason"] == nil { failures.append("degraded event missing reason attribute.") }
                if degraded?.attributes["source"] != "playback" { failures.append("degraded event missing source=playback.") }
                if degraded?.attributes["kind"] == nil { failures.append("degraded event missing kind attribute.") }
                if degraded?.attributes["action"] == nil { failures.append("degraded event missing action attribute.") }

                if let raw = degraded?.attributes["reason"], let reason = DegradeReason(rawValue: raw) {
                    let expected = reason.title
                    if degraded?.label != expected {
                        failures.append("degraded label mismatch: expected \(expected), got \(degraded?.label ?? "nil").")
                    }
                } else {
                    failures.append("degraded event reason not parseable as DegradeReason.")
                }
            }
        }

        return Report(
            name: "3.3.2.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            plan: plan,
            sessionId: finalSession.id,
            segmentChangedCount: segmentChangedCount,
            hasSegmentChangeToSecondSet: hasSegmentChangeToSecondSet,
            degradedEventLabel: degraded?.label,
            degradedAttributes: degraded?.attributes,
            failures: failures
        )
    }

    private func tickIfNeeded(at now: Date) {
        guard var eng = engine else { return }
        _ = eng.tick(at: now)
        engine = eng
    }

    private func makePlaybackCoordinator() -> PlaybackCoordinator {
        let debugSelection = MusicSelection(
            source: .appleMusic,
            type: .track,
            externalId: "debug.fail.track",
            displayTitle: "Debug Track (Simulated Failure)",
            playMode: .continue
        )

        return PlaybackCoordinator(
            selectionProvider: { kind, setIndex in
                if self.simulatePlaybackLoadFailure, kind == .work, setIndex == 1 {
                    return debugSelection
                }
                return nil
            },
            selectionApplier: { _ in
                if self.simulatePlaybackLoadFailure {
                    struct SimulatedPlaybackLoadError: Error {}
                    throw SimulatedPlaybackLoadError()
                }
            },
            failureClassifier: { _ in
                self.simulatePlaybackLoadFailure ? .timeout : .unknown
            },
            onFallback: { kind, outcome in
                Task { @MainActor in
                    guard var eng = self.engine else { return }
                    eng.recordDegrade(
                        outcome.degradeReason,
                        attributes: [
                            "source": "playback",
                            "kind": kind.rawValue,
                            "action": String(describing: outcome.action),
                        ]
                    )
                    self.engine = eng
                }
            }
        )
    }
}

@MainActor
private final class AutoAcceptance_3_3_3_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var sessionId: UUID?
        var fetchedSessionsCount: Int
        var connectivityIsOnlineObserved: Bool
        var communityCachedCountAfterOnlineLoad: Int
        var communityCachedCountAfterOfflineLoad: Int
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    private let store: CoreDataPersistenceStore

    private init(store: CoreDataPersistenceStore) {
        self.store = store
    }

    static func run(store: CoreDataPersistenceStore) async -> Report {
        let runner = AutoAcceptance_3_3_3_1(store: store)
        return await runner.run()
    }

    private func run() async -> Report {
        var failures: [String] = []

        // 0) Verify debug override (if provided): ConnectivityMonitor reads -forceOffline/-forceOnline.
        let connectivityObserved = ConnectivityMonitor().isOnline

        // A) "Offline training/history" is fundamentally local persistence — simulate by writing then reading.
        let plan = Plan(setsCount: 2, workSeconds: 1, restSeconds: 0, name: "Auto Acceptance 3.3.3.1")
        var engine = try? WorkoutSessionEngine(plan: plan, now: Date(timeIntervalSince1970: 0))
        _ = engine?.tick(at: Date(timeIntervalSince1970: 3))
        let session = engine?.session
        if let session {
            await store.upsertSession(session)
        } else {
            failures.append("Failed to create/persist a session.")
        }

        let fetched = await store.fetchAllSessions()
        if fetched.isEmpty {
            failures.append("Expected >=1 persisted sessions, got 0.")
        }

        // B) Community offline behavior: if online, cache summaries; offline uses cache only.
        let viewModel = CommunityFeedViewModel()
        await viewModel.load(isOnline: true)
        let cachedAfterOnline = viewModel.summaries.count
        if cachedAfterOnline == 0 {
            failures.append("Expected cached community summaries after online load.")
        }

        await viewModel.load(isOnline: false)
        let cachedAfterOffline = viewModel.summaries.count
        if cachedAfterOffline != cachedAfterOnline {
            failures.append("Expected offline load to show cached summaries only (count mismatch).")
        }

        return Report(
            name: "3.3.3.1",
            passed: failures.isEmpty,
            createdAt: Date(),
            sessionId: session?.id,
            fetchedSessionsCount: fetched.count,
            connectivityIsOnlineObserved: connectivityObserved,
            communityCachedCountAfterOnlineLoad: cachedAfterOnline,
            communityCachedCountAfterOfflineLoad: cachedAfterOffline,
            failures: failures
        )
    }
}

@MainActor
private final class AutoAcceptance_3_4_2_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var exportedSchemaVersion: Int
        var exportedCounts: Counts
        var importedCounts: Counts
        var failures: [String]

        struct Counts: Codable, Sendable, Equatable {
            var plans: Int
            var sessions: Int
            var planVersions: Int
            var hasRecoverableSnapshot: Bool
        }

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    private let store: CoreDataPersistenceStore

    private init(store: CoreDataPersistenceStore) {
        self.store = store
    }

    static func run(store: CoreDataPersistenceStore) async -> Report {
        let runner = AutoAcceptance_3_4_2_1(store: store)
        return await runner.run()
    }

    private func run() async -> Report {
        var failures: [String] = []

        // Seed minimal data: plan + session + planVersion + recoverable snapshot
        let plan = Plan(setsCount: 2, workSeconds: 5, restSeconds: 0, name: "Backup Seed Plan")
        await store.upsertPlan(plan)

        let startedAt = Date(timeIntervalSince1970: 10)
        let endedAt = Date(timeIntervalSince1970: 25)
        let planSnapshot = PlanSnapshot(
            planId: plan.id,
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name,
            capturedAt: startedAt
        )
        let session = Session(
            id: UUID(),
            status: .completed,
            startedAt: startedAt,
            endedAt: endedAt,
            planSnapshot: planSnapshot,
            completedSets: 2,
            totalSets: 2,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            events: [.completed(occurredAt: endedAt)]
        )
        await store.upsertSession(session)

        let version = PlanVersion(
            planId: plan.id,
            status: .draft,
            versionNumber: 1,
            setsCount: plan.setsCount,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            name: plan.name,
            createdAt: startedAt,
            updatedAt: endedAt
        )
        try? await store.upsertPlanVersion(version)

        let recoverable = RecoverableSessionSnapshot(session: session, elapsedSeconds: 7, capturedAt: Date(timeIntervalSince1970: 20))
        await store.upsertRecoverableSessionSnapshot(recoverable)

        // Export
        let exported = await store.exportBackupBundle(exportedAt: Date(timeIntervalSince1970: 0))
        let exportedCounts = Report.Counts(
            plans: exported.plans.count,
            sessions: exported.sessions.count,
            planVersions: exported.planVersions.count,
            hasRecoverableSnapshot: exported.recoverableSessionSnapshot != nil
        )

        // Reset then Import (overwrite)
        await store.resetAllData()
        do {
            try await store.importBackupBundle(exported, overwrite: true)
        } catch {
            failures.append("Import threw: \(String(describing: error))")
        }

        let importedPlans = await store.fetchAllPlans()
        let importedSessions = await store.fetchAllSessions()
        let importedVersions = await store.fetchAllPlanVersions()
        let importedRecoverable = await store.fetchRecoverableSessionSnapshot()
        let importedCounts = Report.Counts(
            plans: importedPlans.count,
            sessions: importedSessions.count,
            planVersions: importedVersions.count,
            hasRecoverableSnapshot: importedRecoverable != nil
        )

        if importedPlans.first?.id != plan.id { failures.append("Plan not restored.") }
        if importedSessions.first?.id != session.id { failures.append("Session not restored.") }
        if importedVersions.first?.id != version.id { failures.append("PlanVersion not restored.") }
        if importedRecoverable?.elapsedSeconds != 7 { failures.append("Recoverable snapshot not restored.") }

        let passed = failures.isEmpty
        return Report(
            name: "3.4.2.1",
            passed: passed,
            createdAt: Date(),
            exportedSchemaVersion: exported.schemaVersion,
            exportedCounts: exportedCounts,
            importedCounts: importedCounts,
            failures: failures
        )
    }
}

private enum AutoAcceptance_3_4_1_1 {
    struct Report: Codable, Sendable {
        var name: String
        var passed: Bool
        var createdAt: Date
        var status: String
        var failures: [String]

        func persist(filename: String) async {
            do {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(filename)
                let data = try JSONEncoder.prettyISO8601.encode(self)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("[AutoAcceptance] Failed to persist report: %@", String(describing: error))
            }
        }
    }

    static func statusString(_ status: ICloudBackupStatus?) -> String {
        guard let status else { return "nil" }
        switch status {
        case .disabled:
            return "disabled"
        case .containerUnavailable:
            return "containerUnavailable"
        case let .succeeded(path):
            return "succeeded:\(path)"
        case let .failed(message):
            return "failed:\(message)"
        }
    }
}

private extension JSONEncoder {
    static var prettyISO8601: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}
#endif
