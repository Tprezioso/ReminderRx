//
//  Schedule.swift
//  ReminderRxKit
//

import Foundation

/// When a medication should be taken. Stored on `Medication` as encoded JSON.
public struct Schedule: Codable, Hashable, Sendable {
    public enum Frequency: Codable, Hashable, Sendable {
        case daily
        /// Calendar weekday numbers, 1 = Sunday … 7 = Saturday.
        case weekdays(Set<Int>)
        case everyNDays(interval: Int, start: Date)
        case asNeeded
    }

    public var frequency: Frequency
    public var times: [DoseTime]

    public init(frequency: Frequency, times: [DoseTime]) {
        self.frequency = frequency
        self.times = times
    }

    public static let `default` = Schedule(frequency: .daily, times: [DoseTime(hour: 9, minute: 0)])

    public var isAsNeeded: Bool {
        if case .asNeeded = frequency { return true }
        return false
    }

    public var sortedTimes: [DoseTime] {
        times.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    /// Average units consumed per day, or `nil` when the usage can't be predicted.
    public var averageDailyQuantity: Double? {
        let perDay = Double(times.reduce(0) { $0 + $1.quantity })
        guard perDay > 0 else { return nil }
        switch frequency {
        case .daily:
            return perDay
        case .weekdays(let days):
            return days.isEmpty ? nil : perDay * Double(days.count) / 7
        case .everyNDays(let interval, _):
            return perDay / Double(max(interval, 1))
        case .asNeeded:
            return nil
        }
    }
}

public struct DoseTime: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var hour: Int
    public var minute: Int
    /// Units taken at this time (pills, puffs, mL…).
    public var quantity: Int

    public init(id: UUID = UUID(), hour: Int, minute: Int, quantity: Int = 1) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.quantity = quantity
    }
}
