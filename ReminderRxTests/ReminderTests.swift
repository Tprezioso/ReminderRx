//
//  ReminderTests.swift
//  ReminderRxTests
//

import Foundation
@testable import ReminderRxKit
import SwiftData
import Testing
import UserNotifications

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
}

private func medication(
    times: [DoseTime] = [DoseTime(hour: 8, minute: 0)],
    remindersEnabled: Bool = true,
    isLow: Bool = false,
    logged: Set<Date> = []
) -> ReminderMedication {
    let id = UUID()
    return ReminderMedication(
        id: id,
        name: "Lisinopril",
        dosage: "10 mg",
        form: .tablet,
        snapshot: MedicationSnapshot(id: id, schedule: Schedule(frequency: .daily, times: times), activeFrom: date(1, 0)),
        remindersEnabled: remindersEnabled,
        isLowOnSupply: isLow,
        pillsRemaining: isLow ? 3 : 30,
        loggedDates: logged
    )
}

@Suite struct ReminderPlannerTests {
    let planner = ReminderPlanner(scheduler: DoseScheduler(calendar: calendar))

    func settings(nudges: Bool = false, budget: Int = 60, days: Int = 3) -> ReminderSettings {
        var settings = ReminderSettings()
        settings.nudgesEnabled = nudges
        settings.budget = budget
        settings.horizonDays = days
        return settings
    }

    @Test func schedulesUpcomingDosesAndSkipsLoggedOnes() {
        let med = medication(logged: [date(5, 8)])
        let plan = planner.plan(for: [med], settings: settings(), refillAlertDates: [:], now: date(4, 9))
        // Mar 4 8am is past, Mar 5 is logged, Mar 6 remains.
        #expect(plan.reminders.map(\.fireDate) == [date(6, 8)])
        #expect(plan.reminders.first?.title == "Time for Lisinopril")
        #expect(plan.reminders.first?.body == "Take 1 tablet · 10 mg")
        #expect(plan.reminders.first?.reference == ReminderReference(medicationID: med.id, scheduledDate: date(6, 8)))
    }

    @Test func remindersOffMeansNoDoseReminders() {
        let plan = planner.plan(for: [medication(remindersEnabled: false)], settings: settings(), refillAlertDates: [:], now: date(4, 9))
        #expect(plan.reminders.isEmpty)
    }

    @Test func nudgeStillComingForARecentUnloggedDose() {
        let plan = planner.plan(for: [medication()], settings: settings(nudges: true, days: 1), refillAlertDates: [:], now: date(4, 8, 10))
        #expect(plan.reminders.map(\.kind) == [.nudge])
        #expect(plan.reminders.first?.fireDate == date(4, 8, 30))
    }

    @Test func budgetIsRespectedWithKeepAlive() {
        let times = (6...21).map { DoseTime(hour: $0, minute: 0) } // 16 doses a day
        let plan = planner.plan(for: [medication(times: times)], settings: settings(budget: 20, days: 14), refillAlertDates: [:], now: date(4, 0))
        #expect(plan.isTruncated)
        #expect(plan.reminders.count == 20)
        #expect(plan.reminders.last?.kind == .keepAlive)
    }

    @Test func refillAlertsOncePerLowSupplyEpisode() {
        let low = medication(remindersEnabled: false, isLow: true)
        let now = date(4, 12)

        let first = planner.plan(for: [low], settings: settings(), refillAlertDates: [:], now: now)
        #expect(first.reminders.map(\.kind) == [.refill])
        #expect(first.reminders.first?.fireDate == date(5, 10))

        // Once that alert has fired, it isn't repeated while still low.
        let later = planner.plan(for: [low], settings: settings(), refillAlertDates: first.refillAlertDates, now: date(5, 11))
        #expect(later.reminders.isEmpty)
        #expect(later.refillAlertDates[low.id] == date(5, 10))

        // Back above the threshold ends the episode.
        var restocked = low
        restocked.isLowOnSupply = false
        let reset = planner.plan(for: [restocked], settings: settings(), refillAlertDates: later.refillAlertDates, now: date(6, 9))
        #expect(reset.refillAlertDates.isEmpty)
    }

    @Test func referenceSurvivesUserInfoRoundTrip() {
        let reference = ReminderReference(medicationID: UUID(), scheduledDate: date(4, 8))
        #expect(ReminderReference(userInfo: reference.userInfo) == reference)
        #expect(ReminderReference(userInfo: [:]) == nil)
    }
}

@MainActor
final class FakeNotificationCenter: NotificationScheduling {
    var pending: [String: UNNotificationRequest] = [:]
    var delivered: [String] = []

    func pendingIdentifiers() async -> [String] { Array(pending.keys) }
    func deliveredIdentifiers() async -> [String] { delivered }
    func add(_ request: UNNotificationRequest) async throws { pending[request.identifier] = request }
    func removePending(_ identifiers: [String]) { identifiers.forEach { pending[$0] = nil } }
    func removeDelivered(_ identifiers: [String]) { delivered.removeAll { identifiers.contains($0) } }
}

@MainActor
@Suite struct ReminderSchedulerTests {
    @Test func applyReplacesPlannedRemindersAndKeepsUnrelatedOnes() async {
        let center = FakeNotificationCenter()
        let medicationID = UUID()
        let logged = DoseKey(medicationID: medicationID, scheduledDate: date(4, 8)).rawValue
        let open = DoseKey(medicationID: medicationID, scheduledDate: date(4, 20)).rawValue

        for identifier in ["dose.stale", "snooze.\(logged)", "snooze.\(open)", "someone-else"] {
            try? await center.add(UNNotificationRequest(identifier: identifier, content: UNNotificationContent(), trigger: nil))
        }
        center.delivered = ["dose.\(logged)", "nudge.\(open)"]

        let planner = ReminderPlanner(scheduler: DoseScheduler(calendar: calendar))
        var settings = ReminderSettings()
        settings.nudgesEnabled = false
        settings.horizonDays = 1
        let med = medication(times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)], logged: [date(4, 8)])
        let plan = planner.plan(for: [med], settings: settings, refillAlertDates: [:], now: date(4, 7))
        #expect(plan.reminders.map(\.fireDate) == [date(4, 20)])

        await ReminderScheduler.apply(plan, loggedDoses: [logged], to: center)

        let identifiers = Set(center.pending.keys)
        #expect(!identifiers.contains("dose.stale"))
        #expect(!identifiers.contains("snooze.\(logged)"))
        #expect(identifiers.contains("snooze.\(open)"))
        #expect(identifiers.contains("someone-else"))
        #expect(identifiers.isSuperset(of: plan.reminders.map(\.identifier)))
        #expect(center.delivered == ["nudge.\(open)"])

        let request = center.pending[plan.reminders[0].identifier]
        #expect(request?.content.categoryIdentifier == ReminderCategory.dose)
        #expect(request?.content.interruptionLevel == .timeSensitive)
        let components = (request?.trigger as? UNCalendarNotificationTrigger)?.dateComponents
        #expect(components.flatMap { calendar.date(from: $0) } == date(4, 20))
    }
}

@MainActor
@Suite struct ReminderResponseHandlerTests {
    let container = try! SharedStore.makeContainer(inMemory: true)

    @Test func notificationActionsUpdateDosesAndSupply() async {
        let medication = Medication(name: "Atorvastatin", schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 20, minute: 0)]), pillsRemaining: 3, quantityPerFill: 30, refillsRemaining: 1)
        container.mainContext.insert(medication)
        let reference = ReminderReference(medicationID: medication.id, scheduledDate: date(4, 20))

        await ReminderResponseHandler.handle(action: ReminderAction.take, reference: reference, title: "", body: "", context: container.mainContext)
        #expect(medication.log(forScheduledDate: date(4, 20))?.status == .taken)
        #expect(medication.pillsRemaining == 2)

        await ReminderResponseHandler.handle(action: ReminderAction.skip, reference: reference, title: "", body: "", context: container.mainContext)
        #expect(medication.log(forScheduledDate: date(4, 20))?.status == .skipped)
        #expect(medication.pillsRemaining == 3)

        let refill = ReminderReference(medicationID: medication.id, scheduledDate: nil)
        await ReminderResponseHandler.handle(action: ReminderAction.refilled, reference: refill, title: "", body: "", context: container.mainContext)
        #expect(medication.pillsRemaining == 33)

        // Tapping the notification itself changes nothing.
        await ReminderResponseHandler.handle(action: UNNotificationDefaultActionIdentifier, reference: reference, title: "", body: "", context: container.mainContext)
        #expect(medication.doses?.count == 1)
    }
}
