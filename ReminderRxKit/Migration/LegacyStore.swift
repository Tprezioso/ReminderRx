//
//  LegacyStore.swift
//  ReminderRxKit
//

import CoreData
import Foundation
import SwiftData

/// Reads the ReminderRx 1.x Core Data store and copies it into SwiftData.
public enum LegacyStore {
    /// Reads every prescription from a 1.x store, opened read-only. Uses key-value access so it
    /// doesn't depend on the generated `Prescriptions` class.
    public static func prescriptions(at storeURL: URL, model: NSManagedObjectModel) throws -> [LegacyPrescription] {
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

    /// Inserts prescriptions that aren't already in the store and returns how many were added.
    /// Today's "taken" check mark carries over only when 1.x's date stamp shows it's from today.
    @MainActor
    public static func insert(
        _ prescriptions: [LegacyPrescription],
        into context: ModelContext,
        lastDateString: String?,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> Int {
        let existingIDs = Set(try context.fetch(FetchDescriptor<Medication>()).map(\.id))
        let takenFlagIsCurrent = LegacyMapping.takenFlagIsCurrent(lastDateString: lastDateString, now: now, calendar: calendar)
        let scheduler = DoseScheduler(calendar: calendar)
        var imported = 0

        for (index, legacy) in prescriptions.enumerated() {
            if let id = legacy.id, existingIDs.contains(id) { continue }
            let medication = LegacyMapping.medication(from: legacy, index: index, now: now, calendar: calendar)
            context.insert(medication)

            // Supply was already deducted by 1.x, so only the log is added.
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
