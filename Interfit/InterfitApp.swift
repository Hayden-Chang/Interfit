//
//  InterfitApp.swift
//  Interfit
//
//  Created by pc on 2026/1/21.
//

import SwiftUI

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
        }
    }
}
