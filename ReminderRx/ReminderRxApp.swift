//
//  ReminderRxApp.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/9/21.
//

import SwiftUI
import EventKit

@main
struct ReminderRxApp: App {
    let persistenceController = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
