//
//  SharedStore.swift
//  ReminderRxKit
//

import Foundation
import SwiftData

/// The SwiftData store, kept in the App Group so the app, widgets and intents share it.
public enum SharedStore {
    public static let appGroupID = "group.com.Swifttom.ReminderRx"
    public static let schema = Schema([Medication.self, DoseLog.self])

    public static let container: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("Failed to open the ReminderRx store: \(error)")
        }
    }()

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Settings shared with the widget extension.
    public static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }
}

extension Notification.Name {
    /// Posted on the main actor after `DoseActions` changes data, so the app can reschedule reminders.
    public static let reminderRxDataDidChange = Notification.Name("ReminderRxDataDidChange")
}
