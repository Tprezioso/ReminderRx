//
//  ReminderIdentifiers.swift
//  ReminderRxKit
//

import Foundation

public enum ReminderCategory {
    public static let dose = "DOSE"
    public static let refill = "REFILL"
}

public enum ReminderAction {
    public static let take = "TAKE"
    public static let snooze = "SNOOZE"
    public static let skip = "SKIP"
    public static let refilled = "REFILLED"
    public static let remindTomorrow = "REMIND_TOMORROW"
}

/// What kind of reminder a notification is. The raw value prefixes its identifier.
public enum ReminderKind: String, CaseIterable, Sendable {
    case dose, nudge, snooze, refill, keepAlive

    /// Kinds the planner owns and replaces on every reschedule. Snoozes are left alone.
    static let planned: [ReminderKind] = [.dose, .nudge, .refill, .keepAlive]

    func identifier(_ suffix: String) -> String { "\(rawValue).\(suffix)" }

    static func kind(of identifier: String) -> ReminderKind? {
        allCases.first { identifier.hasPrefix($0.rawValue + ".") }
    }
}

/// The medication (and dose) a notification is about, carried in its `userInfo`.
public struct ReminderReference: Hashable, Sendable {
    private static let medicationIDKey = "medicationID"
    private static let scheduledDateKey = "scheduledDate"

    public var medicationID: UUID
    public var scheduledDate: Date?

    public init(medicationID: UUID, scheduledDate: Date?) {
        self.medicationID = medicationID
        self.scheduledDate = scheduledDate
    }

    public init?(userInfo: [AnyHashable: Any]) {
        guard let idString = userInfo[Self.medicationIDKey] as? String, let id = UUID(uuidString: idString) else {
            return nil
        }
        medicationID = id
        scheduledDate = (userInfo[Self.scheduledDateKey] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
    }

    public var userInfo: [String: Any] {
        var info: [String: Any] = [Self.medicationIDKey: medicationID.uuidString]
        if let scheduledDate {
            info[Self.scheduledDateKey] = scheduledDate.timeIntervalSince1970
        }
        return info
    }
}
