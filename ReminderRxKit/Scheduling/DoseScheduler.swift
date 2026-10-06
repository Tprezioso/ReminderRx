//
//  DoseScheduler.swift
//  ReminderRxKit
//

import Foundation

/// Expands schedules into concrete dose times.
public struct DoseScheduler: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func isScheduled(_ schedule: Schedule, on day: Date) -> Bool {
        switch schedule.frequency {
        case .daily:
            return true
        case .weekdays(let weekdays):
            return weekdays.contains(calendar.component(.weekday, from: day))
        case .everyNDays(let interval, let start):
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: day)
            ).day ?? 0
            return days >= 0 && days % max(interval, 1) == 0
        case .asNeeded:
            return false
        }
    }

    /// Doses scheduled on the calendar day containing `day`, sorted by time.
    public func doses(for medication: MedicationSnapshot, on day: Date) -> [ScheduledDose] {
        guard isActive(medication, on: day), isScheduled(medication.schedule, on: day) else { return [] }
        return medication.schedule.sortedTimes.compactMap { time in
            calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day).map {
                ScheduledDose(medicationID: medication.id, scheduledDate: $0, quantity: time.quantity)
            }
        }
    }

    public func doses(for medications: [MedicationSnapshot], on day: Date) -> [ScheduledDose] {
        medications.flatMap { doses(for: $0, on: day) }.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Doses strictly after `date`, looking ahead `days` calendar days.
    public func upcomingDoses(for medications: [MedicationSnapshot], after date: Date, days: Int) -> [ScheduledDose] {
        let start = calendar.startOfDay(for: date)
        return (0..<days)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .flatMap { doses(for: medications, on: $0) }
            .filter { $0.scheduledDate > date }
    }

    public func nextDose(for medications: [MedicationSnapshot], after date: Date, lookaheadDays: Int = 14) -> ScheduledDose? {
        let start = calendar.startOfDay(for: date)
        for offset in 0..<lookaheadDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if let dose = doses(for: medications, on: day).first(where: { $0.scheduledDate > date }) {
                return dose
            }
        }
        return nil
    }

    /// A medication counts from the day it was added until the day it was archived (exclusive).
    func isActive(_ medication: MedicationSnapshot, on day: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard dayStart >= calendar.startOfDay(for: medication.activeFrom) else { return false }
        if let until = medication.activeUntil, dayStart >= calendar.startOfDay(for: until) { return false }
        return true
    }
}
