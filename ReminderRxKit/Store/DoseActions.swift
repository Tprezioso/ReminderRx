//
//  DoseActions.swift
//  ReminderRxKit
//

import Foundation
import OSLog
import SwiftData
import WidgetKit

/// The single place that logs doses and changes supply. The app, notification actions,
/// widgets and Siri all go through here so the bookkeeping stays consistent.
@MainActor
public struct DoseActions {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Logs a dose as taken and deducts it from supply. Taking an already-taken dose does nothing.
    @discardableResult
    public func markTaken(_ medication: Medication, scheduledDate: Date?, quantity: Int? = nil, at date: Date = .now) -> DoseLog {
        let quantity = quantity ?? medication.quantity(forScheduledDate: scheduledDate)
        if let scheduledDate, let existing = medication.log(forScheduledDate: scheduledDate) {
            if existing.status != .taken {
                existing.status = .taken
                existing.loggedAt = date
                existing.quantity = quantity
                consume(quantity, from: medication)
                commit()
            }
            return existing
        }
        let log = insertLog(for: medication, scheduledDate: scheduledDate, status: .taken, quantity: quantity, at: date)
        consume(quantity, from: medication)
        commit()
        return log
    }

    @discardableResult
    public func skip(_ medication: Medication, scheduledDate: Date, at date: Date = .now) -> DoseLog {
        if let existing = medication.log(forScheduledDate: scheduledDate) {
            if existing.status == .taken {
                restore(existing.quantity, to: medication)
            }
            existing.status = .skipped
            existing.loggedAt = date
            commit()
            return existing
        }
        let log = insertLog(for: medication, scheduledDate: scheduledDate, status: .skipped, quantity: 0, at: date)
        commit()
        return log
    }

    @discardableResult
    public func logAsNeeded(_ medication: Medication, quantity: Int = 1, at date: Date = .now) -> DoseLog {
        markTaken(medication, scheduledDate: nil, quantity: quantity, at: date)
    }

    /// Removes a log, returning a taken dose to supply.
    public func undo(_ log: DoseLog) {
        if log.status == .taken, let medication = log.medication {
            restore(log.quantity, to: medication)
        }
        context.delete(log)
        commit()
    }

    /// Adds one fill to supply and uses up a refill when any are left.
    public func refill(_ medication: Medication) {
        medication.pillsRemaining += medication.quantityPerFill
        medication.refillsRemaining = max(medication.refillsRemaining - 1, 0)
        commit()
    }

    public func medication(id: UUID) -> Medication? {
        var descriptor = FetchDescriptor<Medication>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Saves and tells widgets and the reminder scheduler that data changed.
    public func commit() {
        do {
            try context.save()
        } catch {
            Logger(subsystem: "com.Swifttom.ReminderRx", category: "DoseActions").error("Failed to save: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .reminderRxDataDidChange, object: nil)
    }

    // MARK: - Private

    private func insertLog(for medication: Medication, scheduledDate: Date?, status: DoseLogStatus, quantity: Int, at date: Date) -> DoseLog {
        let log = DoseLog(scheduledDate: scheduledDate, loggedAt: date, status: status, quantity: quantity)
        context.insert(log)
        log.medication = medication
        return log
    }

    private func consume(_ quantity: Int, from medication: Medication) {
        guard medication.tracksSupply else { return }
        medication.pillsRemaining = max(medication.pillsRemaining - quantity, 0)
    }

    private func restore(_ quantity: Int, to medication: Medication) {
        guard medication.tracksSupply else { return }
        medication.pillsRemaining += quantity
    }
}
