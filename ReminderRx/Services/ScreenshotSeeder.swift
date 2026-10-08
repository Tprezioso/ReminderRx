//
//  ScreenshotSeeder.swift
//  ReminderRx
//

#if DEBUG
import Foundation
import ReminderRxKit
import SwiftData

/// Replaces the store with sample medications and three weeks of history when the app is
/// launched with `-seedScreenshotData`. Debug builds only; used for App Store screenshots.
enum ScreenshotSeeder {
    static func seedIfRequested(into context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedScreenshotData") else { return }

        try? context.delete(model: DoseLog.self)
        try? context.delete(model: Medication.self)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -21, to: today)!

        let medications = [
            Medication(name: "Lisinopril", dosage: "10 mg", form: .tablet, color: .blue,
                       schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 8, minute: 0)]),
                       pillsRemaining: 24, refillsRemaining: 2, createdAt: start),
            Medication(name: "Metformin", dosage: "500 mg", form: .tablet, color: .purple,
                       schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 21, minute: 0)]),
                       pillsRemaining: 41, quantityPerFill: 60, refillsRemaining: 3, createdAt: start),
            Medication(name: "Levothyroxine", dosage: "50 mcg", form: .tablet, color: .pink,
                       schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 7, minute: 0)]),
                       pillsRemaining: 5, refillsRemaining: 1, createdAt: start),
            Medication(name: "Vitamin D3", dosage: "2000 IU", form: .capsule, color: .orange,
                       schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 12, minute: 30)]),
                       pillsRemaining: 70, quantityPerFill: 90, createdAt: start),
            Medication(name: "Atorvastatin", dosage: "20 mg", form: .tablet, color: .teal,
                       schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 22, minute: 0)]),
                       pillsRemaining: 18, refillsRemaining: 5, createdAt: start),
            Medication(name: "Albuterol", dosage: "90 mcg", form: .inhaler, color: .green,
                       schedule: Schedule(frequency: .asNeeded, times: []),
                       pillsRemaining: 140, quantityPerFill: 200, createdAt: start),
        ]
        medications.forEach(context.insert)

        // Mostly-taken history with a handful of skips and misses, so the chart looks real.
        var rng = SeededGenerator(seed: 42)
        for (index, medication) in medications.enumerated() where !medication.schedule.isAsNeeded {
            for dayOffset in 0...21 {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: start)!
                for time in medication.schedule.times {
                    let scheduled = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)!
                    guard scheduled < .now else { continue }
                    // The last 10 days stay on track so the streak looks earned.
                    let roll = dayOffset > 11 ? 99 : Int.random(in: 0..<100, using: &rng)
                    if roll < 4 + index { continue } // missed
                    let status: DoseLogStatus = roll < 7 + index ? .skipped : .taken
                    let log = DoseLog(scheduledDate: scheduled,
                                      loggedAt: scheduled.addingTimeInterval(Double(Int.random(in: 0...1200, using: &rng))),
                                      status: status, quantity: time.quantity)
                    log.medication = medication
                    context.insert(log)
                }
            }
        }
        if let albuterol = medications.last {
            for daysAgo in [2, 9, 16] {
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!.addingTimeInterval(15 * 3600)
                let log = DoseLog(scheduledDate: nil, loggedAt: date, status: .taken, quantity: 2)
                log.medication = albuterol
                context.insert(log)
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

/// Deterministic generator so every capture shows the same history.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
#endif
