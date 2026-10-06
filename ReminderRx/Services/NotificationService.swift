//
//  NotificationService.swift
//  ReminderRx
//

import Observation
import ReminderRxKit
import UIKit
import UserNotifications

/// Notification permission state for the UI, and the app's entry point for rescheduling reminders.
@Observable
final class NotificationService {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var isAuthorized: Bool {
        [.authorized, .provisional, .ephemeral].contains(authorizationStatus)
    }

    func refresh() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asks for permission if it hasn't been asked yet, and schedules reminders once granted.
    func requestAuthorizationIfNeeded() async {
        await refresh()
        guard authorizationStatus == .notDetermined else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refresh()
        if isAuthorized {
            await ReminderScheduler.rescheduleNow()
        }
    }

    /// Called when the app becomes active: picks up permission changes made in Settings
    /// and tops up the rolling window of scheduled reminders.
    func appDidBecomeActive() async {
        await refresh()
        await ReminderScheduler.rescheduleNow()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
