//
//  InterfitApp.swift
//  Interfit
//
//  Created by pc on 2026/1/21.
//

import SwiftUI
import UIKit

@main
struct InterfitApp: App {
    let persistenceController = PersistenceController.shared
    private let arguments = ProcessInfo.processInfo.arguments
    private var shouldLaunchModulesDemo: Bool { arguments.contains("-modulesDemo") }
    private var shouldLaunchPlanEditor: Bool { arguments.contains("-planEditor") }
    private var shouldStartPlanEditorInModeB: Bool { arguments.contains("-planEditorModeB") }

    var body: some Scene {
        WindowGroup {
            Group {
                if shouldLaunchModulesDemo {
                    NavigationStack {
                        ModulesDemoView()
                    }
                } else if shouldLaunchPlanEditor {
                    NavigationStack {
                        PlanEditorView(plan: nil, startInModeB: shouldStartPlanEditorInModeB)
                    }
                } else {
                    RootTabView()
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Force-quit from app switcher often skips `willTerminate`.
                // Pause here to guarantee "close app => pause owned playback".
                MusicPlaybackClient.pauseIfOwnedByInterfitForAppTermination()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                MusicPlaybackClient.pauseIfOwnedByInterfitForAppTermination()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { _ in
                MusicPlaybackClient.pauseIfOwnedByInterfitForAppTermination()
            }
        }
    }
}
