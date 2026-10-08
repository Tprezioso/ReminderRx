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
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationService = NotificationService()
    private let container = SharedStore.container

    init() {
        LegacyImporter.importIfNeeded(into: container.mainContext)
        #if DEBUG
        ScreenshotSeeder.seedIfRequested(into: container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppRouter.shared)
                .environment(notificationService)
                .fontDesign(.rounded)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await notificationService.appDidBecomeActive() }
        }
    }
}
