//
//  MedicationEditorModel.swift
//  ReminderRx
//

import Foundation
import Observation
import ReminderRxKit
import SwiftData

/// Editable copy of a medication's fields. Nothing touches the store until `save`.
@Observable
final class MedicationEditorModel {
    enum FrequencyKind: String, CaseIterable, Identifiable {
        case daily, weekdays, interval, asNeeded

        var id: Self { self }

        var title: String {
            switch self {
            case .daily: "Every Day"
            case .weekdays: "Specific Days"
            case .interval: "Every Few Days"
            case .asNeeded: "As Needed"
            }
        }
    }

    static let symbolChoices = [
        "pills.fill", "capsule.fill", "capsule.portrait.fill", "cross.vial.fill",
        "drop.fill", "syringe.fill", "lungs.fill", "eyedropper.halffull",
        "bandage.fill", "heart.fill", "bolt.heart.fill", "brain.head.profile",
        "allergens.fill", "leaf.fill", "sun.max.fill", "moon.fill",
    ]

    let medication: Medication?

    var name = ""
    var dosage = ""
    var form: MedicationForm = .tablet {
        didSet {
            // Keep the icon in step with the form unless it was picked by hand.
            if symbolName == oldValue.symbolName { symbolName = form.symbolName }
        }
    }
    var color: MedColor = .blue
    var symbolName = MedicationForm.tablet.symbolName
    var notes = ""

    var frequency: FrequencyKind = .daily
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var interval = 2
    var intervalStart = Date.now
    var times: [DoseTime] = [DoseTime(hour: 9, minute: 0)]
    var remindersEnabled = true

    var tracksSupply = true
    var pillsRemaining = 30
    var quantityPerFill = 30
    var refillsRemaining = 0
    var lowSupplyThreshold = 7

    var isNew: Bool { medication == nil }

    init(medication: Medication?, colorIndex: Int = 0, defaultLowSupplyThreshold: Int = 7) {
        self.medication = medication
        guard let medication else {
            color = .cycling(colorIndex)
            lowSupplyThreshold = defaultLowSupplyThreshold
            return
        }
        name = medication.name
        dosage = medication.dosage
        form = medication.form
        color = medication.color
        symbolName = medication.symbolName
        notes = medication.notes
        remindersEnabled = medication.remindersEnabled
        tracksSupply = medication.tracksSupply
        pillsRemaining = medication.pillsRemaining
        quantityPerFill = medication.quantityPerFill
        refillsRemaining = medication.refillsRemaining
        lowSupplyThreshold = medication.lowSupplyThreshold

        let schedule = medication.schedule
        times = schedule.sortedTimes
        switch schedule.frequency {
        case .daily:
            frequency = .daily
        case .weekdays(let days):
            frequency = .weekdays
            weekdays = days
        case .everyNDays(let interval, let start):
            frequency = .interval
            self.interval = interval
            intervalStart = start
        case .asNeeded:
            frequency = .asNeeded
            if times.isEmpty { times = [DoseTime(hour: 9, minute: 0)] }
        }
    }

    var schedule: Schedule {
        switch frequency {
        case .daily: Schedule(frequency: .daily, times: times)
        case .weekdays: Schedule(frequency: .weekdays(weekdays), times: times)
        case .interval: Schedule(frequency: .everyNDays(interval: interval, start: intervalStart), times: times)
        // As-needed keeps one entry so the quantity per dose is remembered.
        case .asNeeded: Schedule(frequency: .asNeeded, times: Array(times.prefix(1)))
        }
    }

    var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give your medication a name." }
        if frequency != .asNeeded && times.isEmpty { return "Add at least one time to take it." }
        if frequency == .weekdays && weekdays.isEmpty { return "Pick at least one day." }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

    func addTime() {
        let last = times.max { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        let hour = last.map { min($0.hour + 4, 23) } ?? 9
        times.append(DoseTime(hour: hour, minute: last?.minute ?? 0, quantity: last?.quantity ?? 1))
    }

    func save(in context: ModelContext) {
        let target = medication ?? Medication(name: "")
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        target.form = form
        target.color = color
        target.symbolName = symbolName
        target.notes = notes
        target.schedule = schedule
        target.remindersEnabled = remindersEnabled && frequency != .asNeeded
        target.tracksSupply = tracksSupply
        target.pillsRemaining = max(pillsRemaining, 0)
        target.quantityPerFill = max(quantityPerFill, 0)
        target.refillsRemaining = max(refillsRemaining, 0)
        target.lowSupplyThreshold = max(lowSupplyThreshold, 0)
        if medication == nil {
            context.insert(target)
        }
        DoseActions(context: context).commit()
    }
}
