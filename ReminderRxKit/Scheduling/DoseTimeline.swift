//
//  DoseTimeline.swift
//  ReminderRxKit
//

import Foundation

public enum DoseStatus: Hashable, Sendable {
    case upcoming
    /// Time has passed recently and nothing is logged yet.
    case due
    case missed
    case taken
    case skipped
}

/// A scheduled dose joined with its medication and log, ready for display.
public struct DoseEntry: Identifiable {
    public var medication: Medication
    public var dose: ScheduledDose
    public var log: DoseLog?
    public var status: DoseStatus

    public var id: String { dose.id }
}

public enum DoseTimeline {
    /// How long after its time a dose still counts as "due" rather than "missed".
    public static let dueWindow: TimeInterval = 2 * 60 * 60

    /// Every scheduled dose on the day containing `day`, with its status relative to `now`.
    @MainActor
    public static func entries(
        for medications: [Medication],
        on day: Date,
        now: Date = .now,
        scheduler: DoseScheduler = DoseScheduler()
    ) -> [DoseEntry] {
        medications
            .filter { !$0.isArchived }
            .flatMap { medication in
                scheduler.doses(for: medication.snapshot, on: day).map { dose in
                    let log = medication.log(forScheduledDate: dose.scheduledDate)
                    return DoseEntry(
                        medication: medication,
                        dose: dose,
                        log: log,
                        status: status(of: dose, log: log, now: now)
                    )
                }
            }
            .sorted { ($0.dose.scheduledDate, $0.medication.name) < ($1.dose.scheduledDate, $1.medication.name) }
    }

    public static func status(of dose: ScheduledDose, log: DoseLog?, now: Date) -> DoseStatus {
        switch log?.status {
        case .taken: return .taken
        case .skipped: return .skipped
        case nil:
            if dose.scheduledDate > now { return .upcoming }
            return now.timeIntervalSince(dose.scheduledDate) <= dueWindow ? .due : .missed
        }
    }
}
