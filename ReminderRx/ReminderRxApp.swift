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
    }

    var body: some Scene {
        WindowGroup {
            TemporaryHomeView()
                .environment(notificationService)
                .task {
                    // Onboarding (Phase 3) will take over asking for permission.
                    await notificationService.requestAuthorizationIfNeeded()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await notificationService.appDidBecomeActive() }
        }
    }
}
