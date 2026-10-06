//
//  Schedule+Description.swift
//  ReminderRxKit
//

import Foundation

extension DoseTime {
    /// The time on an arbitrary day, for formatting and pickers.
    public func date(on day: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    public var formatted: String {
        date().formatted(date: .omitted, time: .shortened)
    }
}

extension Schedule {
    /// How often, e.g. "Daily", "Mon, Wed, Fri", "Every 3 days", "As needed".
    public var frequencyDescription: String {
        switch frequency {
        case .daily:
            return "Daily"
        case .weekdays(let days):
            if days == [2, 3, 4, 5, 6] { return "Weekdays" }
            if days == [1, 7] { return "Weekends" }
            if days.count == 7 { return "Daily" }
            let symbols = Calendar.current.shortWeekdaySymbols
            return days.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
        case .everyNDays(let interval, _):
            return interval == 1 ? "Daily" : "Every \(interval) days"
        case .asNeeded:
            return "As needed"
        }
    }

    /// One-line summary, e.g. "2× daily · 8:00 AM, 8:00 PM".
    public var summary: String {
        guard !isAsNeeded, !times.isEmpty else { return frequencyDescription }
        let times = sortedTimes.map(\.formatted).joined(separator: ", ")
        if frequencyDescription == "Daily", sortedTimes.count > 1 {
            return "\(sortedTimes.count)× daily · \(times)"
        }
        return "\(frequencyDescription) · \(times)"
    }
}
