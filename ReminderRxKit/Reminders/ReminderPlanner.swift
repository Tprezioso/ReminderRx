//
//  ReminderPlanner.swift
//  ReminderRxKit
//

import Foundation

/// The parts of a medication the planner needs, as plain values.
public struct ReminderMedication: Sendable {
    public var id: UUID
    public var name: String
    public var dosage: String
    public var form: MedicationForm
    public var snapshot: MedicationSnapshot
    public var remindersEnabled: Bool
    public var isLowOnSupply: Bool
    public var pillsRemaining: Int
    /// Scheduled times that already have a log, so they don't get a reminder.
    public var loggedDates: Set<Date>

    public init(id: UUID, name: String, dosage: String, form: MedicationForm, snapshot: MedicationSnapshot, remindersEnabled: Bool, isLowOnSupply: Bool, pillsRemaining: Int, loggedDates: Set<Date>) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.form = form
        self.snapshot = snapshot
        self.remindersEnabled = remindersEnabled
        self.isLowOnSupply = isLowOnSupply
        self.pillsRemaining = pillsRemaining
        self.loggedDates = loggedDates
    }
}

extension Medication {
    public var reminderInput: ReminderMedication {
        ReminderMedication(
            id: id,
            name: name,
            dosage: dosage,
            form: form,
            snapshot: snapshot,
            remindersEnabled: remindersEnabled,
            isLowOnSupply: isLowOnSupply,
            pillsRemaining: pillsRemaining,
            loggedDates: Set((doses ?? []).compactMap(\.scheduledDate))
        )
    }
}

public struct ReminderSettings: Sendable {
    public static let nudgesEnabledKey = "missedDoseNudgesEnabled"
    public static let refillAlertsEnabledKey = "refillAlertsEnabled"

    public var nudgesEnabled = true
    public var refillAlertsEnabled = true
    public var nudgeDelay: TimeInterval = 30 * 60
    /// Nudges only go out for doses this soon, so they don't crowd out dose reminders.
    public var nudgeHorizon: TimeInterval = 48 * 60 * 60
    public var horizonDays = 14
    /// iOS keeps at most 64 pending notifications per app; a few are left for snoozes.
    public var budget = 60
    public var refillHour = 10

    public init() {}

    public static var current: ReminderSettings {
        let defaults = SharedStore.defaults
        var settings = ReminderSettings()
        settings.nudgesEnabled = defaults.object(forKey: nudgesEnabledKey) as? Bool ?? true
        settings.refillAlertsEnabled = defaults.object(forKey: refillAlertsEnabledKey) as? Bool ?? true
        return settings
    }
}

public struct PlannedReminder: Hashable, Sendable {
    public var kind: ReminderKind
    public var identifier: String
    public var fireDate: Date
    public var title: String
    public var body: String
    public var reference: ReminderReference?
    public var category: String?
    public var threadID: String
}

public struct ReminderPlan: Sendable {
    public var reminders: [PlannedReminder]
    /// When each low-supply medication's refill alert fires (or fired). Persisted between plans
    /// so each low-supply episode alerts once, not every day.
    public var refillAlertDates: [UUID: Date]
    public var isTruncated: Bool
}

/// Decides which local notifications should be pending. Pure, so it can be tested without iOS.
public struct ReminderPlanner: Sendable {
    public var scheduler: DoseScheduler
    private var calendar: Calendar { scheduler.calendar }

    public init(scheduler: DoseScheduler = DoseScheduler()) {
        self.scheduler = scheduler
    }

    public func plan(
        for medications: [ReminderMedication],
        settings: ReminderSettings,
        refillAlertDates: [UUID: Date],
        now: Date
    ) -> ReminderPlan {
        var reminders: [PlannedReminder] = []
        var alertDates: [UUID: Date] = [:]

        if settings.refillAlertsEnabled {
            for medication in medications where medication.isLowOnSupply {
                let fireDate = refillAlertDates[medication.id] ?? nextOccurrence(ofHour: settings.refillHour, after: now)
                alertDates[medication.id] = fireDate
                if fireDate > now {
                    reminders.append(refillReminder(for: medication, at: fireDate))
                }
            }
        }

        // One slot is held back for the keep-alive reminder.
        let budget = max(settings.budget - reminders.count - 1, 0)
        let byID = Dictionary(uniqueKeysWithValues: medications.map { ($0.id, $0) })
        let doses = scheduler.upcomingDoses(
            for: medications.filter(\.remindersEnabled).map(\.snapshot),
            after: now.addingTimeInterval(-settings.nudgeDelay),
            days: settings.horizonDays
        )

        var doseReminders: [PlannedReminder] = []
        var isTruncated = false
        for dose in doses {
            guard let medication = byID[dose.medicationID], !medication.loggedDates.contains(dose.scheduledDate) else { continue }

            var candidates: [PlannedReminder] = []
            if dose.scheduledDate > now {
                candidates.append(doseReminder(for: medication, dose: dose))
            }
            let nudgeDate = dose.scheduledDate.addingTimeInterval(settings.nudgeDelay)
            if settings.nudgesEnabled, nudgeDate > now, nudgeDate <= now.addingTimeInterval(settings.nudgeHorizon) {
                candidates.append(nudgeReminder(for: medication, dose: dose, at: nudgeDate))
            }
            guard doseReminders.count + candidates.count <= budget else {
                isTruncated = true
                break
            }
            doseReminders += candidates
        }

        if isTruncated, let last = doseReminders.map(\.fireDate).max() {
            reminders.append(keepAliveReminder(at: last.addingTimeInterval(60)))
        }

        return ReminderPlan(
            reminders: (reminders + doseReminders).sorted { $0.fireDate < $1.fireDate },
            refillAlertDates: alertDates,
            isTruncated: isTruncated
        )
    }

    public func nextOccurrence(ofHour hour: Int, after date: Date) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0), matchingPolicy: .nextTime) ?? date
    }

    // MARK: - Content

    private func doseReminder(for medication: ReminderMedication, dose: ScheduledDose) -> PlannedReminder {
        var details = ["Take \(dose.quantity) \(medication.form.unitName(for: dose.quantity))"]
        if !medication.dosage.isEmpty { details.append(medication.dosage) }
        if medication.isLowOnSupply { details.append("\(medication.pillsRemaining) left") }

        return PlannedReminder(
            kind: .dose,
            identifier: ReminderKind.dose.identifier(dose.id),
            fireDate: dose.scheduledDate,
            title: "Time for \(medication.name)",
            body: details.joined(separator: " · "),
            reference: ReminderReference(medicationID: medication.id, scheduledDate: dose.scheduledDate),
            category: ReminderCategory.dose,
            threadID: medication.id.uuidString
        )
    }

    private func nudgeReminder(for medication: ReminderMedication, dose: ScheduledDose, at fireDate: Date) -> PlannedReminder {
        let time = dose.scheduledDate.formatted(date: .omitted, time: .shortened)
        return PlannedReminder(
            kind: .nudge,
            identifier: ReminderKind.nudge.identifier(dose.id),
            fireDate: fireDate,
            title: "Did you take \(medication.name)?",
            body: "Your \(time) dose hasn't been logged yet.",
            reference: ReminderReference(medicationID: medication.id, scheduledDate: dose.scheduledDate),
            category: ReminderCategory.dose,
            threadID: medication.id.uuidString
        )
    }

    private func refillReminder(for medication: ReminderMedication, at fireDate: Date) -> PlannedReminder {
        let unit = medication.form.unitName(for: medication.pillsRemaining)
        return PlannedReminder(
            kind: .refill,
            identifier: ReminderKind.refill.identifier(medication.id.uuidString),
            fireDate: fireDate,
            title: "Time to refill \(medication.name)",
            body: "Only \(medication.pillsRemaining) \(unit) left.",
            reference: ReminderReference(medicationID: medication.id, scheduledDate: nil),
            category: ReminderCategory.refill,
            threadID: "refills"
        )
    }

    private func keepAliveReminder(at fireDate: Date) -> PlannedReminder {
        PlannedReminder(
            kind: .keepAlive,
            identifier: ReminderKind.keepAlive.identifier("next"),
            fireDate: fireDate,
            title: "Keep your reminders coming",
            body: "Open ReminderRx so it can schedule your upcoming doses.",
            reference: nil,
            category: nil,
            threadID: "app"
        )
    }
}
