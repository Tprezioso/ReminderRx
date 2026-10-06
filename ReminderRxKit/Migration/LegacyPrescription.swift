//
//  LegacyPrescription.swift
//  ReminderRxKit
//

import Foundation

/// A prescription as stored by ReminderRx 1.x in Core Data, where every count was a `String`.
public struct LegacyPrescription: Sendable {
    public var id: UUID?
    public var name: String?
    public var count: String?
    public var countTotal: String?
    public var refills: String?
    /// "Taken today", as of the last day 1.x was opened.
    public var isOn: Bool
    public var isNotificationOn: Bool
    /// The reminder time.
    public var savedDate: Date?

    public init(id: UUID?, name: String?, count: String?, countTotal: String?, refills: String?, isOn: Bool, isNotificationOn: Bool, savedDate: Date?) {
        self.id = id
        self.name = name
        self.count = count
        self.countTotal = countTotal
        self.refills = refills
        self.isOn = isOn
        self.isNotificationOn = isNotificationOn
        self.savedDate = savedDate
    }
}

public enum LegacyMapping {
    /// The day-stamp format 1.x stored under the `lastDateString` user default.
    public static let lastDateFormat = "d MM y"

    /// Converts a 1.x prescription. 1.x tracked one dose a day, so it becomes a daily schedule at
    /// the saved reminder time, with reminders on only if they were on before.
    public static func medication(
        from legacy: LegacyPrescription,
        index: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Medication {
        let time = legacy.savedDate.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let doseTime = DoseTime(hour: time?.hour ?? 9, minute: time?.minute ?? 0)
        let remaining = int(legacy.count)
        let perFill = int(legacy.countTotal)

        return Medication(
            id: legacy.id ?? UUID(),
            name: legacy.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Medication",
            color: .cycling(index),
            schedule: Schedule(frequency: .daily, times: [doseTime]),
            remindersEnabled: legacy.isNotificationOn,
            pillsRemaining: remaining,
            quantityPerFill: perFill > 0 ? perFill : max(remaining, 30),
            refillsRemaining: int(legacy.refills),
            createdAt: now
        )
    }

    /// Whether 1.x's "taken today" flag is about today. 1.x only reset the flag when opened on
    /// a new day, so a stale flag from an earlier day must be ignored.
    public static func takenFlagIsCurrent(lastDateString: String?, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let lastDateString else { return false }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = lastDateFormat
        return formatter.string(from: now) == lastDateString
    }

    static func int(_ string: String?) -> Int {
        max(Int(string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0, 0)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
