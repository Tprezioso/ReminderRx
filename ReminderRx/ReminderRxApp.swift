//
//  ReminderRxApp.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/9/21.
//

import ReminderRxKit
import SwiftData
import SwiftUI

@main
struct ReminderRxApp: App {
    private let container = SharedStore.container

    init() {
        LegacyImporter.importIfNeeded(into: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            TemporaryHomeView()
        }
        .modelContainer(container)
    }
}
