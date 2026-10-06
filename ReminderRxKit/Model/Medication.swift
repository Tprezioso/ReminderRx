//
//  Medication.swift
//  ReminderRxKit
//

import Foundation
import SwiftData

@Model
public final class Medication {
    public var id: UUID = UUID()
    public var name: String = ""
    /// Free-form strength, e.g. "10 mg".
    public var dosage: String = ""
    var formRaw: String = MedicationForm.tablet.rawValue
    var colorRaw: String = MedColor.blue.rawValue
    public var symbolName: String = MedicationForm.tablet.symbolName
    public var notes: String = ""

    // Stored as JSON because SwiftData can't persist enums with associated values reliably.
    var scheduleData: Data = Data()
    public var remindersEnabled: Bool = true

    public var tracksSupply: Bool = true
    public var pillsRemaining: Int = 0
    public var quantityPerFill: Int = 30
    public var refillsRemaining: Int = 0
    public var lowSupplyThreshold: Int = 7

    public var createdAt: Date = Date()
    public var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    public var doses: [DoseLog]? = []

    public init(
        id: UUID = UUID(),
        name: String,
        dosage: String = "",
        form: MedicationForm = .tablet,
        color: MedColor = .blue,
        symbolName: String? = nil,
        notes: String = "",
        schedule: Schedule = .default,
        remindersEnabled: Bool = true,
        tracksSupply: Bool = true,
        pillsRemaining: Int = 0,
        quantityPerFill: Int = 30,
        refillsRemaining: Int = 0,
        lowSupplyThreshold: Int = 7,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.formRaw = form.rawValue
        self.colorRaw = color.rawValue
        self.symbolName = symbolName ?? form.symbolName
        self.notes = notes
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        self.remindersEnabled = remindersEnabled
        self.tracksSupply = tracksSupply
        self.pillsRemaining = pillsRemaining
        self.quantityPerFill = quantityPerFill
        self.refillsRemaining = refillsRemaining
        self.lowSupplyThreshold = lowSupplyThreshold
        self.createdAt = createdAt
    }

    public var form: MedicationForm {
        get { MedicationForm(rawValue: formRaw) ?? .other }
        set { formRaw = newValue.rawValue }
    }

    public var color: MedColor {
        get { MedColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    public var schedule: Schedule {
        get { (try? JSONDecoder().decode(Schedule.self, from: scheduleData)) ?? .default }
        set { scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    public var isArchived: Bool { archivedAt != nil }

    public var isLowOnSupply: Bool {
        tracksSupply && pillsRemaining <= lowSupplyThreshold
    }

    /// Whole days of supply left at the scheduled rate, or `nil` when it can't be predicted.
    public var daysOfSupplyLeft: Int? {
        guard tracksSupply, let perDay = schedule.averageDailyQuantity else { return nil }
        return Int((Double(pillsRemaining) / perDay).rounded(.down))
    }

    /// The quantity scheduled at the time of `scheduledDate`, falling back to 1.
    public func quantity(forScheduledDate scheduledDate: Date?, calendar: Calendar = .current) -> Int {
        guard let scheduledDate else { return 1 }
        let parts = calendar.dateComponents([.hour, .minute], from: scheduledDate)
        return schedule.times.first { $0.hour == parts.hour && $0.minute == parts.minute }?.quantity ?? 1
    }

    public func log(forScheduledDate scheduledDate: Date) -> DoseLog? {
        doses?.first { $0.scheduledDate == scheduledDate }
    }

    public var snapshot: MedicationSnapshot {
        MedicationSnapshot(id: id, schedule: schedule, activeFrom: createdAt, activeUntil: archivedAt)
    }
}
