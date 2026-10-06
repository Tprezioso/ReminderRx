//
//  DoseLog.swift
//  ReminderRxKit
//

import Foundation
import SwiftData

public enum DoseLogStatus: String, Codable, Sendable {
    case taken, skipped
}

/// A dose the user acted on. Missed doses are never stored; they're derived from the schedule.
@Model
public final class DoseLog {
    public var id: UUID = UUID()
    /// The scheduled time this log answers, or `nil` for an as-needed dose.
    public var scheduledDate: Date?
    public var loggedAt: Date = Date()
    var statusRaw: String = DoseLogStatus.taken.rawValue
    public var quantity: Int = 1
    public var medication: Medication?

    public init(scheduledDate: Date?, loggedAt: Date = .now, status: DoseLogStatus, quantity: Int) {
        self.scheduledDate = scheduledDate
        self.loggedAt = loggedAt
        self.statusRaw = status.rawValue
        self.quantity = quantity
    }

    public var status: DoseLogStatus {
        get { DoseLogStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    public var snapshot: LogSnapshot? {
        guard let medicationID = medication?.id else { return nil }
        return LogSnapshot(medicationID: medicationID, scheduledDate: scheduledDate, status: status)
    }
}
