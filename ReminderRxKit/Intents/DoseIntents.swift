//
//  DoseIntents.swift
//  ReminderRxKit
//

import AppIntents
import Foundation
import SwiftData
import SwiftUI

/// Logs a dose as taken. Used by widget buttons (with a scheduled time) and Siri (without one).
public struct MarkDoseTakenIntent: AppIntent {
    public static let title: LocalizedStringResource = "Take Medication"
    public static let description = IntentDescription("Logs a dose of a medication as taken.")

    @Parameter(title: "Medication")
    public var medication: MedicationEntity

    /// The dose being answered. When omitted, the earliest dose today that isn't logged yet.
    @Parameter(title: "Scheduled Time")
    public var scheduledDate: Date?

    public static var parameterSummary: some ParameterSummary {
        Summary("Take \(\.$medication)")
    }

    public init() {}

    public init(medication: MedicationEntity, scheduledDate: Date?) {
        self.medication = medication
        self.scheduledDate = scheduledDate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let actions = DoseActions(context: SharedStore.container.mainContext)
        guard let target = actions.medication(id: medication.id) else { throw MedicationIntentError.notFound }

        if let date = scheduledDate ?? DoseLookup.actionableDose(for: target)?.dose.scheduledDate {
            actions.markTaken(target, scheduledDate: date)
        } else if target.schedule.isAsNeeded {
            actions.logAsNeeded(target, quantity: target.schedule.times.first?.quantity ?? 1)
        } else {
            return .result(dialog: "You've already logged every \(target.name) dose for today.")
        }
        await ReminderScheduler.rescheduleNow(context: actions.context)
        return .result(dialog: "Logged \(target.name). Nice work!")
    }
}

public struct SkipDoseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Skip Medication Dose"
    public static let description = IntentDescription("Marks a scheduled dose as skipped.")

    @Parameter(title: "Medication")
    public var medication: MedicationEntity

    @Parameter(title: "Scheduled Time")
    public var scheduledDate: Date?

    public static var parameterSummary: some ParameterSummary {
        Summary("Skip \(\.$medication)")
    }

    public init() {}

    public init(medication: MedicationEntity, scheduledDate: Date?) {
        self.medication = medication
        self.scheduledDate = scheduledDate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let actions = DoseActions(context: SharedStore.container.mainContext)
        guard let target = actions.medication(id: medication.id) else { throw MedicationIntentError.notFound }
        guard let date = scheduledDate ?? DoseLookup.actionableDose(for: target)?.dose.scheduledDate else {
            return .result(dialog: "There's no \(target.name) dose left to skip today.")
        }
        actions.skip(target, scheduledDate: date)
        await ReminderScheduler.rescheduleNow(context: actions.context)
        return .result(dialog: "Skipped \(target.name).")
    }
}

public struct LogAsNeededDoseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log As-Needed Dose"
    public static let description = IntentDescription("Logs a dose of a medication you take as needed.")

    @Parameter(title: "Medication")
    public var medication: MedicationEntity

    public static var parameterSummary: some ParameterSummary {
        Summary("Log a dose of \(\.$medication)")
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let actions = DoseActions(context: SharedStore.container.mainContext)
        guard let target = actions.medication(id: medication.id) else { throw MedicationIntentError.notFound }
        actions.logAsNeeded(target, quantity: target.schedule.times.first?.quantity ?? 1)
        await ReminderScheduler.rescheduleNow(context: actions.context)
        return .result(dialog: "Logged a dose of \(target.name).")
    }
}

/// "Take my next dose" — for Control Center, the Action button and Siri.
public struct TakeNextDoseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Take Next Dose"
    public static let description = IntentDescription("Logs the dose that's due now, or one coming up within the hour.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.container.mainContext
        guard let entry = DoseLookup.actionableDose(in: context) else {
            return .result(dialog: "Nothing's due right now. You're all caught up!")
        }
        DoseActions(context: context).markTaken(entry.medication, scheduledDate: entry.dose.scheduledDate)
        await ReminderScheduler.rescheduleNow(context: context)
        return .result(dialog: "Logged \(entry.medication.name). Nice work!")
    }
}

public struct NextDoseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Next Medication"
    public static let description = IntentDescription("Tells you which medication is next and when.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let next = DoseLookup.nextDose(in: SharedStore.container.mainContext) else {
            return .result(dialog: "You don't have any upcoming doses.", view: NextDoseSnippet(name: nil, detail: "No upcoming doses", color: .indigo, symbolName: "checkmark.circle.fill"))
        }
        let time = next.date.formatted(date: .omitted, time: .shortened)
        let day = Calendar.current.isDateInToday(next.date) ? "" : " \(next.date.formatted(.relative(presentation: .named)))"
        return .result(
            dialog: "Your next medication is \(next.medication.name) at \(time)\(day).",
            view: NextDoseSnippet(
                name: next.medication.name,
                detail: [time, next.medication.dosage].filter { !$0.isEmpty }.joined(separator: " · "),
                color: next.medication.color.color,
                symbolName: next.medication.symbolName
            )
        )
    }
}

struct NextDoseSnippet: View {
    let name: String?
    let detail: String
    let color: Color
    let symbolName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(color.gradient, in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                if let name {
                    Text(name).font(.headline)
                }
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .fontDesign(.rounded)
    }
}
