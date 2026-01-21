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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
