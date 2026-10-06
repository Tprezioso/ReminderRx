//
//  DoseLookup.swift
//  ReminderRxKit
//

import Foundation
import SwiftData

/// Finds "the dose you mean" for widgets, controls and Siri.
@MainActor
public enum DoseLookup {
    /// How far ahead "take my next dose" reaches for a dose that isn't due yet.
    public static let earlyWindow: TimeInterval = 60 * 60

    public static func activeMedications(in context: ModelContext) -> [Medication] {
        let descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The earliest overdue dose today, or else one coming up within the hour.
    public static func actionableDose(in context: ModelContext, now: Date = .now) -> DoseEntry? {
        let entries = DoseTimeline.entries(for: activeMedications(in: context), on: now, now: now)
        if let overdue = entries.first(where: { $0.status == .due || $0.status == .missed }) {
            return overdue
        }
        return entries.first { $0.status == .upcoming && $0.dose.scheduledDate.timeIntervalSince(now) <= earlyWindow }
    }

    /// The dose of `medication` someone most likely means when they say they took it today:
    /// the earliest one not yet logged.
    public static func actionableDose(for medication: Medication, now: Date = .now) -> DoseEntry? {
        DoseTimeline.entries(for: [medication], on: now, now: now)
            .first { $0.status != .taken && $0.status != .skipped }
    }

    /// The next dose that hasn't been logged, today or later.
    public static func nextDose(in context: ModelContext, now: Date = .now) -> (medication: Medication, date: Date)? {
        let medications = activeMedications(in: context)
        if let entry = DoseTimeline.entries(for: medications, on: now, now: now)
            .first(where: { $0.status == .upcoming || $0.status == .due }) {
            return (entry.medication, entry.dose.scheduledDate)
        }
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        guard let dose = DoseScheduler().nextDose(for: medications.map(\.snapshot), after: tomorrow.addingTimeInterval(-1)),
              let medication = medications.first(where: { $0.id == dose.medicationID }) else {
            return nil
        }
        return (medication, dose.scheduledDate)
    }
}
