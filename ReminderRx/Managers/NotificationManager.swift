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
    
    func removeAllNotifications(id: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
            for request in requests {
                if request.identifier == id {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [request.identifier])
                }
            }
        }
    }
}
