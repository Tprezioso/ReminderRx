//
//  Snapshots.swift
//  ReminderRxKit
//

import Foundation

/// Value copies of the model objects, so scheduling and stats math stays pure and testable.
public struct MedicationSnapshot: Hashable, Sendable {
    public var id: UUID
    public var schedule: Schedule
    public var activeFrom: Date
    public var activeUntil: Date?

    public init(id: UUID, schedule: Schedule, activeFrom: Date, activeUntil: Date? = nil) {
        self.id = id
        self.schedule = schedule
        self.activeFrom = activeFrom
        self.activeUntil = activeUntil
    }
}

public struct LogSnapshot: Hashable, Sendable {
    public var medicationID: UUID
    public var scheduledDate: Date?
    public var status: DoseLogStatus

    public init(medicationID: UUID, scheduledDate: Date?, status: DoseLogStatus) {
        self.medicationID = medicationID
        self.scheduledDate = scheduledDate
        self.status = status
    }
}

public struct ScheduledDose: Hashable, Sendable, Identifiable {
    public var medicationID: UUID
    public var scheduledDate: Date
    public var quantity: Int

    public init(medicationID: UUID, scheduledDate: Date, quantity: Int) {
        self.medicationID = medicationID
        self.scheduledDate = scheduledDate
        self.quantity = quantity
    }

    public var id: String { DoseKey(medicationID: medicationID, scheduledDate: scheduledDate).rawValue }
}

/// Identifies one scheduled dose of one medication. Also used as the notification identifier.
public struct DoseKey: Hashable, Sendable {
    public var medicationID: UUID
    public var scheduledDate: Date

    public init(medicationID: UUID, scheduledDate: Date) {
        self.medicationID = medicationID
        self.scheduledDate = scheduledDate
    }

    public var rawValue: String {
        "\(medicationID.uuidString)@\(Int(scheduledDate.timeIntervalSince1970))"
    }
}
