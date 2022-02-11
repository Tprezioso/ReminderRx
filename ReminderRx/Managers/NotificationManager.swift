//
//  NotificationManager.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 2/11/22.
//

import Foundation
import UserNotifications

final class NotificationManager: ObservableObject {
    @Published private var notification: [UNNotificationRequest] = []
    @Published var authorizationStatus: UNAuthorizationStatus?
    
    func reloadAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, _ in
            DispatchQueue.main.async {
                self.authorizationStatus = isGranted ? .authorized : .denied
            }
        }
    }
    
    func reloadLocalNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { notifications in
            DispatchQueue.main.async {
                self.notification = notifications
            }
        }
    }
}
