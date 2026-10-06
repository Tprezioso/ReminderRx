//
//  MigrationAndLookupTests.swift
//  ReminderRxTests
//

import CoreData
import Foundation
import ReminderRxKit
import SwiftData
import Testing

private let calendar = Calendar.current

private func today(_ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now)!
}

/// The 1.x `Prescriptions` entity, mirroring `Prescriptions.xcdatamodeld`.
private func legacyModel() -> NSManagedObjectModel {
    func attribute(_ name: String, _ type: NSAttributeDescription.AttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.type = type
        attribute.isOptional = true
        return attribute
    }
    let entity = NSEntityDescription()
    entity.name = "Prescriptions"
    entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
    entity.properties = [
        attribute("id", .uuid),
        attribute("name", .string),
        attribute("count", .string),
        attribute("countTotal", .string),
        attribute("refills", .string),
        attribute("isOn", .boolean),
        attribute("isNotificationOn", .boolean),
        attribute("savedDate", .date),
    ]
    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
}

@MainActor
@Suite struct LegacyStoreTests {
    let model = legacyModel()

    /// Writes a 1.x-style SQLite store with the given rows and returns its URL.
    func makeStore(_ rows: [[String: Any]]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "Legacy-\(UUID().uuidString).sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = coordinator
        for row in rows {
            let object = NSManagedObject(entity: model.entitiesByName["Prescriptions"]!, insertInto: context)
            row.forEach { object.setValue($1, forKey: $0) }
        }
        try context.save()
        return url
    }

    @Test func readsAndImportsA1xStore() throws {
        let lisinoprilID = UUID()
        let url = try makeStore([
            ["id": lisinoprilID, "name": "Lisinopril", "count": "12", "countTotal": "30", "refills": "2",
             "isOn": true, "isNotificationOn": true, "savedDate": today(8)],
            ["id": UUID(), "name": "Vitamin D", "count": "45", "countTotal": "90", "refills": "",
             "isOn": false, "isNotificationOn": false, "savedDate": today(21, 30)],
        ])

        let prescriptions = try LegacyStore.prescriptions(at: url, model: model)
        #expect(prescriptions.count == 2)

        let container = try SharedStore.makeContainer(inMemory: true)
        // 1.x's own "last opened" stamp for today.
        let formatter = DateFormatter()
        formatter.dateFormat = LegacyMapping.lastDateFormat
        let stamp = formatter.string(from: .now)
        let imported = try LegacyStore.insert(prescriptions, into: container.mainContext, lastDateString: stamp, now: today(12))
        #expect(imported == 2)

        let medications = try container.mainContext.fetch(FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.name)]))
        let lisinopril = try #require(medications.first)
        #expect(lisinopril.id == lisinoprilID)
        #expect(lisinopril.pillsRemaining == 12)
        #expect(lisinopril.refillsRemaining == 2)
        #expect(lisinopril.remindersEnabled)
        // Today's check mark carried over, stamped at the scheduled time, without touching supply.
        #expect(lisinopril.doses?.count == 1)
        #expect(lisinopril.log(forScheduledDate: today(8))?.loggedAt == today(8))
        #expect(medications[1].doses?.isEmpty == true)
        #expect(!medications[1].remindersEnabled)

        // Running the import again doesn't duplicate anything.
        #expect(try LegacyStore.insert(prescriptions, into: container.mainContext, lastDateString: stamp, now: today(12)) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Medication>()) == 2)
    }

    @Test func staleTakenFlagIsIgnored() throws {
        let url = try makeStore([["id": UUID(), "name": "Lisinopril", "count": "12", "isOn": true, "savedDate": today(8)]])
        let container = try SharedStore.makeContainer(inMemory: true)
        _ = try LegacyStore.insert(
            LegacyStore.prescriptions(at: url, model: model),
            into: container.mainContext,
            lastDateString: "1 01 2020",
            now: today(12)
        )
        let medication = try #require(try container.mainContext.fetch(FetchDescriptor<Medication>()).first)
        #expect(medication.doses?.isEmpty == true)
    }
}

@MainActor
@Suite struct DoseLookupTests {
    let container = try! SharedStore.makeContainer(inMemory: true)

    func insertMedication(_ name: String, times: [DoseTime]) -> Medication {
        let medication = Medication(
            name: name,
            schedule: Schedule(frequency: .daily, times: times),
            pillsRemaining: 30,
            createdAt: calendar.date(byAdding: .day, value: -1, to: .now)!
        )
        container.mainContext.insert(medication)
        return medication
    }

    @Test func picksOverdueFirstThenSoonUpcoming() {
        let context = container.mainContext
        let medication = insertMedication("Lisinopril", times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)])

        #expect(DoseLookup.actionableDose(in: context, now: today(8, 30))?.dose.scheduledDate == today(8))

        DoseActions(context: context).markTaken(medication, scheduledDate: today(8))
        // 8 PM is more than an hour away at 8:30 AM.
        #expect(DoseLookup.actionableDose(in: context, now: today(8, 30)) == nil)
        #expect(DoseLookup.actionableDose(in: context, now: today(19, 30))?.dose.scheduledDate == today(20))
    }

    @Test func nextDoseRollsOverToTomorrow() throws {
        let context = container.mainContext
        let medication = insertMedication("Vitamin D", times: [DoseTime(hour: 9, minute: 0)])
        #expect(DoseLookup.actionableDose(for: medication, now: today(7))?.dose.scheduledDate == today(9))

        DoseActions(context: context).markTaken(medication, scheduledDate: today(9))
        let next = try #require(DoseLookup.nextDose(in: context, now: today(10)))
        #expect(next.date == calendar.date(byAdding: .day, value: 1, to: today(9)))
    }

    @Test func archivedMedicationsAreIgnored() {
        let medication = insertMedication("Old", times: [DoseTime(hour: 8, minute: 0)])
        medication.archivedAt = .now
        #expect(DoseLookup.actionableDose(in: container.mainContext, now: today(8, 30)) == nil)
    }
}

@Suite struct ScheduleDescriptionTests {
    @Test func frequencyNames() {
        #expect(Schedule(frequency: .weekdays([2, 3, 4, 5, 6]), times: []).frequencyDescription == "Weekdays")
        #expect(Schedule(frequency: .weekdays([1, 7]), times: []).frequencyDescription == "Weekends")
        #expect(Schedule(frequency: .everyNDays(interval: 3, start: .now), times: []).frequencyDescription == "Every 3 days")
        #expect(Schedule(frequency: .asNeeded, times: [DoseTime(hour: 9, minute: 0)]).summary == "As needed")
    }

    @Test func summaryCountsDailyTimes() {
        let schedule = Schedule(frequency: .daily, times: [DoseTime(hour: 20, minute: 0), DoseTime(hour: 8, minute: 0)])
        #expect(schedule.summary.hasPrefix("2× daily · "))
        #expect(schedule.summary.contains(DoseTime(hour: 8, minute: 0).formatted))
    }
}
