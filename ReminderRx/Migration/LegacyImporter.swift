//
//  LegacyImporter.swift
//  ReminderRx
//

import CoreData
import Foundation
import OSLog
import ReminderRxKit
import SwiftData
import UserNotifications

/// Copies prescriptions from the 1.x Core Data store into SwiftData, once.
/// The old store is left on disk untouched in case anything needs to be recovered.
enum LegacyImporter {
    private static let didImportKey = "didImportLegacyCoreData"
    private static let importedCountKey = "legacyImportedCount"
    private static let logger = Logger(subsystem: "com.Swifttom.ReminderRx", category: "LegacyImporter")

    /// How many prescriptions the import brought over, for the "What's new" screen.
    static var importedCount: Int { UserDefaults.standard.integer(forKey: importedCountKey) }

    static func importIfNeeded(into context: ModelContext, now: Date = .now) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didImportKey) else { return }

        let storeURL = NSPersistentContainer.defaultDirectoryURL().appending(path: "Prescriptions.sqlite")
        guard FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)) else {
            defaults.set(true, forKey: didImportKey)
            return
        }

        do {
            guard let modelURL = Bundle.main.url(forResource: "Prescriptions", withExtension: "momd"),
                  let model = NSManagedObjectModel(contentsOf: modelURL) else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            let prescriptions = try LegacyStore.prescriptions(at: storeURL, model: model)
            let imported = try LegacyStore.insert(
                prescriptions,
                into: context,
                lastDateString: defaults.string(forKey: "lastDateString"),
                now: now
            )
            // 1.x reminders used each prescription's UUID as the identifier; the new
            // notification service reschedules everything from the imported data.
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            logger.info("Imported \(imported) legacy prescriptions")
            defaults.set(imported, forKey: importedCountKey)
            defaults.set(true, forKey: didImportKey)
        } catch {
            // Leave the flag unset so the import is retried on next launch.
            logger.error("Legacy import failed: \(error)")
        }
    }
}
