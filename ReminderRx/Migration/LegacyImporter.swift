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
    private static let statusKey = "legacyImportStatus"
    private static let logger = Logger(subsystem: "com.Swifttom.ReminderRx", category: "LegacyImporter")

    /// How many prescriptions the import brought over, for the "What's new" screen.
    static var importedCount: Int { UserDefaults.standard.integer(forKey: importedCountKey) }

    /// The last import error, shown in Settings so a failed migration can be diagnosed.
    /// Other outcomes stay in the device log only.
    static var failure: String? {
        UserDefaults.standard.string(forKey: statusKey).flatMap { $0.hasPrefix("Failed") ? $0 : nil }
    }

    static func importIfNeeded(into context: ModelContext, now: Date = .now) {
        let defaults = UserDefaults.standard
        // Done only once something actually came over. Build 5 also marked an import that found
        // nothing as done, so those devices look again.
        guard !(defaults.bool(forKey: didImportKey) && importedCount > 0) else { return }

        let storeURL = NSPersistentContainer.defaultDirectoryURL().appending(path: "Prescriptions.sqlite")
        guard FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)) else {
            record("No 1.x database found", in: defaults)
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
            record("Read \(prescriptions.count), imported \(imported)", in: defaults)
            guard imported > 0 else { return }
            // 1.x reminders used each prescription's UUID as the identifier; the new
            // notification service reschedules everything from the imported data.
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            defaults.set(imported, forKey: importedCountKey)
            defaults.set(true, forKey: didImportKey)
        } catch {
            // Left unfinished so the import is retried on next launch.
            record("Failed: \(error)", in: defaults)
        }
    }

    private static func record(_ status: String, in defaults: UserDefaults) {
        // Notice level so the result is kept in the device log, not just shown while streaming.
        logger.notice("Legacy import: \(status, privacy: .public)")
        defaults.set(status, forKey: statusKey)
    }
}
