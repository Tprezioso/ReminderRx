//
//  AppDelegate.swift
//  ReminderRx
//

import ReminderRxKit
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
        return true
    }

    // Show reminders as banners even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        if action == UNNotificationDefaultActionIdentifier {
            await MainActor.run { AppRouter.shared.selectedTab = .today }
            return
        }
        let content = response.notification.request.content
        guard let reference = ReminderReference(userInfo: content.userInfo) else { return }
        let title = content.title
        let body = content.body
        await ReminderResponseHandler.handle(action: action, reference: reference, title: title, body: body)
    }
}
