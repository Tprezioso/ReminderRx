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
            let prescriptions = try loadPrescriptions(from: storeURL)
            let imported = try insert(prescriptions, into: context, now: now)
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

    private static func loadPrescriptions(from storeURL: URL) throws -> [LegacyPrescription] {
        guard let modelURL = Bundle.main.url(forResource: "Prescriptions", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            type: .sqlite,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        let context = NSManagedObjectContext(.privateQueue)
        context.persistentStoreCoordinator = coordinator

        return try context.performAndWait {
            try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Prescriptions")).map { object in
                LegacyPrescription(
                    id: object.value(forKey: "id") as? UUID,
                    name: object.value(forKey: "name") as? String,
                    count: object.value(forKey: "count") as? String,
                    countTotal: object.value(forKey: "countTotal") as? String,
                    refills: object.value(forKey: "refills") as? String,
                    isOn: object.value(forKey: "isOn") as? Bool ?? false,
                    isNotificationOn: object.value(forKey: "isNotificationOn") as? Bool ?? false,
                    savedDate: object.value(forKey: "savedDate") as? Date
                )
            }
        }
    }

    private static func insert(_ prescriptions: [LegacyPrescription], into context: ModelContext, now: Date) throws -> Int {
        let existingIDs = Set(try context.fetch(FetchDescriptor<Medication>()).map(\.id))
        let takenFlagIsCurrent = LegacyMapping.takenFlagIsCurrent(
            lastDateString: UserDefaults.standard.string(forKey: "lastDateString"),
            now: now
        )
        let scheduler = DoseScheduler()
        var imported = 0

        for (index, legacy) in prescriptions.enumerated() {
            if let id = legacy.id, existingIDs.contains(id) { continue }
            let medication = LegacyMapping.medication(from: legacy, index: index, now: now)
            context.insert(medication)

            // Carry over today's "taken" check mark. Supply was already deducted by 1.x.
            if legacy.isOn, takenFlagIsCurrent,
               let dose = scheduler.doses(for: medication.snapshot, on: now).first {
                // 1.x didn't record when the dose was taken, so assume it was on time.
                let log = DoseLog(scheduledDate: dose.scheduledDate, loggedAt: min(dose.scheduledDate, now), status: .taken, quantity: dose.quantity)
                context.insert(log)
                log.medication = medication
            }
            imported += 1
        }
        try context.save()
        return imported
    }
}
