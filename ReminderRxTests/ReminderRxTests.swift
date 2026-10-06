//
//  ReminderRxTests.swift
//  ReminderRxTests
//

import Foundation
import ReminderRxKit
import SwiftData
import Testing

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func snapshot(_ frequency: Schedule.Frequency, times: [DoseTime] = [DoseTime(hour: 8, minute: 0)], from: Date = date(2026, 1, 1)) -> MedicationSnapshot {
    MedicationSnapshot(id: UUID(), schedule: Schedule(frequency: frequency, times: times), activeFrom: from)
}

@Suite struct DoseSchedulerTests {
    let scheduler = DoseScheduler(calendar: calendar)

    @Test func dailyProducesSortedTimes() {
        let med = snapshot(.daily, times: [DoseTime(hour: 20, minute: 0), DoseTime(hour: 8, minute: 30)])
        let doses = scheduler.doses(for: med, on: date(2026, 3, 4))
        #expect(doses.map(\.scheduledDate) == [date(2026, 3, 4, 8, 30), date(2026, 3, 4, 20)])
    }

    @Test func weekdaysOnlyOnChosenDays() {
        let med = snapshot(.weekdays([2, 4, 6])) // Mon, Wed, Fri
        #expect(scheduler.doses(for: med, on: date(2026, 3, 2)).count == 1) // Monday
        #expect(scheduler.doses(for: med, on: date(2026, 3, 3)).isEmpty) // Tuesday
    }

    @Test func everyNDaysCountsFromStart() {
        let med = snapshot(.everyNDays(interval: 3, start: date(2026, 3, 1)))
        #expect(!scheduler.doses(for: med, on: date(2026, 3, 1)).isEmpty)
        #expect(scheduler.doses(for: med, on: date(2026, 3, 2)).isEmpty)
        #expect(!scheduler.doses(for: med, on: date(2026, 3, 4)).isEmpty)
        #expect(scheduler.doses(for: med, on: date(2026, 2, 26)).isEmpty) // before start
    }

    @Test func asNeededIsNeverScheduled() {
        #expect(scheduler.doses(for: snapshot(.asNeeded), on: date(2026, 3, 4)).isEmpty)
    }

    @Test func nothingBeforeActiveOrAfterArchive() {
        var med = snapshot(.daily, from: date(2026, 3, 10, 15))
        med.activeUntil = date(2026, 3, 12, 9)
        #expect(scheduler.doses(for: med, on: date(2026, 3, 9)).isEmpty)
        #expect(!scheduler.doses(for: med, on: date(2026, 3, 10)).isEmpty)
        #expect(scheduler.doses(for: med, on: date(2026, 3, 12)).isEmpty)
    }

    @Test func handlesDaylightSavingDays() {
        let med = snapshot(.daily, times: [DoseTime(hour: 8, minute: 0)])
        // US spring forward 2026-03-08, fall back 2026-11-01.
        #expect(scheduler.doses(for: med, on: date(2026, 3, 8)).first?.scheduledDate == date(2026, 3, 8, 8))
        #expect(scheduler.doses(for: med, on: date(2026, 11, 1)).first?.scheduledDate == date(2026, 11, 1, 8))
    }

    @Test func nextDoseRollsToTomorrow() {
        let med = snapshot(.daily, times: [DoseTime(hour: 8, minute: 0)])
        let next = scheduler.nextDose(for: [med], after: date(2026, 3, 4, 9))
        #expect(next?.scheduledDate == date(2026, 3, 5, 8))
    }
}

@Suite struct AdherenceTests {
    let calculator = AdherenceCalculator(scheduler: DoseScheduler(calendar: calendar))

    @Test func dayCountsOnlyDueDoses() {
        let med = snapshot(.daily, times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)])
        let logs = [LogSnapshot(medicationID: med.id, scheduledDate: date(2026, 3, 4, 8), status: .taken)]
        let result = calculator.day(date(2026, 3, 4), medications: [med], logs: logs, now: date(2026, 3, 4, 12))
        #expect(result.scheduled == 1)
        #expect(result.taken == 1)
        #expect(result.rate == 1)
    }

    @Test func streakIgnoresIncompleteToday() {
        let med = snapshot(.daily, from: date(2026, 3, 1))
        let logs = (1...3).map { LogSnapshot(medicationID: med.id, scheduledDate: date(2026, 3, $0, 8), status: .taken) }
        // Mar 4 at 7am: today's dose not due yet, previous 3 days complete.
        #expect(calculator.currentStreak(medications: [med], logs: logs, now: date(2026, 3, 4, 7)) == 3)
        // A skipped day breaks it.
        let broken = logs.filter { $0.scheduledDate != date(2026, 3, 2, 8) }
        #expect(calculator.currentStreak(medications: [med], logs: broken, now: date(2026, 3, 4, 7)) == 1)
        #expect(calculator.bestStreak(medications: [med], logs: broken, now: date(2026, 3, 4, 7)) == 1)
    }

    @Test func supplyPrediction() {
        let schedule = Schedule(frequency: .weekdays([2, 3, 4, 5, 6]), times: [DoseTime(hour: 8, minute: 0, quantity: 2)])
        #expect(schedule.averageDailyQuantity == 10.0 / 7)
        #expect(Schedule(frequency: .asNeeded, times: []).averageDailyQuantity == nil)
    }
}

@MainActor
@Suite struct DoseActionsTests {
    let container = try! SharedStore.makeContainer(inMemory: true)

    func makeMedication(pills: Int = 10) -> Medication {
        let medication = Medication(name: "Test", schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 8, minute: 0, quantity: 2)]), pillsRemaining: pills, quantityPerFill: 30, refillsRemaining: 1)
        container.mainContext.insert(medication)
        return medication
    }

    @Test func takeSkipUndoKeepSupplyConsistent() {
        let actions = DoseActions(context: container.mainContext)
        let medication = makeMedication()
        let time = date(2026, 3, 4, 8)

        let log = actions.markTaken(medication, scheduledDate: time)
        #expect(log.quantity == 2)
        #expect(medication.pillsRemaining == 8)

        actions.markTaken(medication, scheduledDate: time) // no double count
        #expect(medication.pillsRemaining == 8)

        actions.skip(medication, scheduledDate: time)
        #expect(medication.pillsRemaining == 10)
        #expect(medication.doses?.count == 1)

        actions.markTaken(medication, scheduledDate: time)
        actions.undo(medication.log(forScheduledDate: time)!)
        #expect(medication.pillsRemaining == 10)
        #expect(medication.doses?.isEmpty == true)
    }

    @Test func refillAddsAFill() {
        let actions = DoseActions(context: container.mainContext)
        let medication = makeMedication(pills: 3)
        actions.refill(medication)
        #expect(medication.pillsRemaining == 33)
        #expect(medication.refillsRemaining == 0)
        actions.refill(medication)
        #expect(medication.refillsRemaining == 0)
    }
}

@Suite struct LegacyMappingTests {
    @Test func mapsStringCountsAndReminderTime() {
        let legacy = LegacyPrescription(id: UUID(), name: " Lisinopril ", count: "12", countTotal: "30", refills: "", isOn: false, isNotificationOn: true, savedDate: date(2026, 1, 1, 21, 15))
        let medication = LegacyMapping.medication(from: legacy, index: 0, calendar: calendar)
        #expect(medication.id == legacy.id)
        #expect(medication.name == "Lisinopril")
        #expect(medication.pillsRemaining == 12)
        #expect(medication.quantityPerFill == 30)
        #expect(medication.refillsRemaining == 0)
        #expect(medication.remindersEnabled)
        #expect(medication.schedule == Schedule(frequency: .daily, times: [DoseTime(id: medication.schedule.times[0].id, hour: 21, minute: 15)]))
    }

    @Test func takenFlagOnlyCountsForToday() {
        let now = date(2026, 3, 4, 10)
        #expect(LegacyMapping.takenFlagIsCurrent(lastDateString: "4 03 2026", now: now, calendar: calendar))
        #expect(!LegacyMapping.takenFlagIsCurrent(lastDateString: "3 03 2026", now: now, calendar: calendar))
        #expect(!LegacyMapping.takenFlagIsCurrent(lastDateString: nil, now: now, calendar: calendar))
    }
}
