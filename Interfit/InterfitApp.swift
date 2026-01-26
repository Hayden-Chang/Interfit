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
    private let shouldLaunchModulesDemo = ProcessInfo.processInfo.arguments.contains("-modulesDemo")

    var body: some Scene {
        WindowGroup {
            Group {
                if shouldLaunchModulesDemo {
                    NavigationStack {
                        ModulesDemoView()
                    }
                } else {
                    RootTabView()
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
