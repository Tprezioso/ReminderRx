//
//  AdherenceCalculator.swift
//  ReminderRxKit
//

import Foundation

public struct DayAdherence: Hashable, Sendable, Identifiable {
    public var day: Date
    /// Scheduled doses whose time has passed (all of them, for past days).
    public var scheduled: Int
    public var taken: Int
    public var skipped: Int

    public var id: Date { day }
    public var missed: Int { max(scheduled - taken - skipped, 0) }
    /// Fraction of due doses taken, or `nil` when nothing was due.
    public var rate: Double? { scheduled == 0 ? nil : Double(taken) / Double(scheduled) }
    public var isComplete: Bool { scheduled > 0 && taken == scheduled }
}

/// Adherence, streak and history math over value snapshots.
public struct AdherenceCalculator: Sendable {
    public var scheduler: DoseScheduler
    private var calendar: Calendar { scheduler.calendar }

    public init(scheduler: DoseScheduler = DoseScheduler()) {
        self.scheduler = scheduler
    }

    public func day(_ day: Date, medications: [MedicationSnapshot], logs: [LogSnapshot], now: Date) -> DayAdherence {
        let statuses = Self.index(logs)
        return adherence(on: day, medications: medications, statuses: statuses, now: now)
    }

    /// One entry per day for the `count` days ending today, oldest first.
    public func lastDays(_ count: Int, medications: [MedicationSnapshot], logs: [LogSnapshot], now: Date) -> [DayAdherence] {
        let statuses = Self.index(logs)
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map {
                adherence(on: $0, medications: medications, statuses: statuses, now: now)
            }
        }
    }

    /// Overall fraction of due doses taken over the last `days` days, or `nil` if nothing was due.
    public func rate(lastDays days: Int, medications: [MedicationSnapshot], logs: [LogSnapshot], now: Date) -> Double? {
        let history = lastDays(days, medications: medications, logs: logs, now: now)
        let scheduled = history.reduce(0) { $0 + $1.scheduled }
        guard scheduled > 0 else { return nil }
        return Double(history.reduce(0) { $0 + $1.taken }) / Double(scheduled)
    }

    /// Consecutive complete days ending today. Today counts only once it is complete, and
    /// an incomplete today doesn't break the streak. Days with nothing scheduled are skipped over.
    public func currentStreak(medications: [MedicationSnapshot], logs: [LogSnapshot], now: Date) -> Int {
        guard let earliest = medications.map(\.activeFrom).min() else { return 0 }
        let statuses = Self.index(logs)
        let firstDay = calendar.startOfDay(for: earliest)
        var day = calendar.startOfDay(for: now)
        var streak = 0

        if wholeDay(day, medications: medications, statuses: statuses).isComplete {
            streak += 1
        }
        while let previous = calendar.date(byAdding: .day, value: -1, to: day), previous >= firstDay {
            day = previous
            let result = wholeDay(day, medications: medications, statuses: statuses)
            if result.scheduled == 0 { continue }
            guard result.isComplete else { break }
            streak += 1
        }
        return streak
    }

    public func bestStreak(medications: [MedicationSnapshot], logs: [LogSnapshot], now: Date) -> Int {
        guard let earliest = medications.map(\.activeFrom).min() else { return 0 }
        let statuses = Self.index(logs)
        let today = calendar.startOfDay(for: now)
        var day = calendar.startOfDay(for: earliest)
        var best = 0
        var run = 0

        while day <= today {
            let result = wholeDay(day, medications: medications, statuses: statuses)
            if result.isComplete {
                run += 1
                best = max(best, run)
            } else if result.scheduled > 0 && day < today {
                run = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    // MARK: - Private

    private func wholeDay(_ day: Date, medications: [MedicationSnapshot], statuses: [DoseKey: DoseLogStatus]) -> DayAdherence {
        adherence(on: day, medications: medications, statuses: statuses, now: .distantFuture)
    }

    private func adherence(on day: Date, medications: [MedicationSnapshot], statuses: [DoseKey: DoseLogStatus], now: Date) -> DayAdherence {
        let due = scheduler.doses(for: medications, on: day).filter { $0.scheduledDate <= now }
        var taken = 0
        var skipped = 0
        for dose in due {
            switch statuses[DoseKey(medicationID: dose.medicationID, scheduledDate: dose.scheduledDate)] {
            case .taken: taken += 1
            case .skipped: skipped += 1
            case nil: break
            }
        }
        return DayAdherence(day: calendar.startOfDay(for: day), scheduled: due.count, taken: taken, skipped: skipped)
    }

    private static func index(_ logs: [LogSnapshot]) -> [DoseKey: DoseLogStatus] {
        var result: [DoseKey: DoseLogStatus] = [:]
        for log in logs {
            guard let date = log.scheduledDate else { continue }
            result[DoseKey(medicationID: log.medicationID, scheduledDate: date)] = log.status
        }
        return result
    }
}
