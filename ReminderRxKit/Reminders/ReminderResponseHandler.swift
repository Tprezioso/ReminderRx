//
//  ReminderResponseHandler.swift
//  ReminderRxKit
//

import Foundation
import SwiftData
import UserNotifications

/// Carries out the action a person picked on a reminder notification.
@MainActor
public enum ReminderResponseHandler {
    public static func handle(
        action: String,
        reference: ReminderReference,
        title: String,
        body: String,
        context: ModelContext? = nil
    ) async {
        let actions = DoseActions(context: context ?? SharedStore.container.mainContext)
        guard let medication = actions.medication(id: reference.medicationID) else { return }

        switch action {
        case ReminderAction.take:
            guard let scheduledDate = reference.scheduledDate else { return }
            actions.markTaken(medication, scheduledDate: scheduledDate)
        case ReminderAction.skip:
            guard let scheduledDate = reference.scheduledDate else { return }
            actions.skip(medication, scheduledDate: scheduledDate)
        case ReminderAction.snooze:
            await ReminderScheduler.snooze(reference, title: title, body: body)
            return
        case ReminderAction.refilled:
            actions.refill(medication)
        case ReminderAction.remindTomorrow:
            await ReminderScheduler.remindRefillTomorrow(medicationID: medication.id)
            return
        default:
            return
        }
        // The app may be suspended right after handling a background action, so don't debounce.
        await ReminderScheduler.rescheduleNow(context: actions.context)
    }
}
