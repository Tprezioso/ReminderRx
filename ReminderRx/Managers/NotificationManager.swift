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
    
    func createLocalNotification(id: String, title: String, hour: Int, minute: Int) async {
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.current
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Time to take your \(title)"
        notificationContent.sound = .default
        
        let request = UNNotificationRequest(identifier: id, content: notificationContent, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print(error)
        }
    }
    
    func removeNotificationWith(id: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
            for request in requests {
                if request.identifier == id {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [request.identifier])
                }
            }
        }
    }
    
    func updateLocalNotification(id: String, title: String, hour: Int, minute: Int) async {
        let notifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
        if notifications.isEmpty {
            await self.createLocalNotification(id: id, title: title, hour: hour, minute: minute)
        } else {
            for request in notifications {
                if request.identifier == id {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [request.identifier])
                    await self.createLocalNotification(id: id, title: title, hour: hour, minute: minute)
                }
            }
        }
    }
}
