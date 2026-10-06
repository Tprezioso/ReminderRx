//
//  TodayView.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query private var logs: [DoseLog]
    @AppStorage("dismissedMissedBannerDay") private var dismissedMissedBannerDay = ""
    @State private var isCelebrating = false
    @State private var backdatingEntry: DoseEntry?

    private var actions: DoseActions { DoseActions(context: modelContext) }
    private var activeMedications: [Medication] { medications.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                content(now: context.date)
            }
            .navigationTitle("Today")
            .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { router.isShowingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Medication", systemImage: "plus") { router.editor = .new }
                }
            }
            .overlay {
                if isCelebrating {
                    CelebrationView()
                        .transition(.opacity)
                        .task {
                            try? await Task.sleep(for: .seconds(2.4))
                            withAnimation { isCelebrating = false }
                        }
                }
            }
            .sheet(item: $backdatingEntry) { entry in
                BackdateDoseSheet(entry: entry) { date in
                    actions.markTaken(entry.medication, scheduledDate: entry.dose.scheduledDate, at: date)
                }
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if activeMedications.isEmpty {
            ContentUnavailableView {
                Label("No medications yet", systemImage: "pills.fill")
            } description: {
                Text("Add your first medication to track doses and get reminders.")
            } actions: {
                Button("Add Medication") { router.editor = .new }
                    .buttonStyle(.glassProminent)
            }
            .background(BrandBackground())
        } else {
            timeline(now: now)
        }
    }

    private func timeline(now: Date) -> some View {
        let entries = DoseTimeline.entries(for: activeMedications, on: now, now: now)
        let taken = entries.filter { $0.status == .taken }.count
        let streak = AdherenceCalculator().currentStreak(
            medications: medications.map(\.snapshot),
            logs: logs.compactMap(\.snapshot),
            now: now
        )

        return List {
            Section {
                TodayHeader(
                    taken: taken,
                    total: entries.count,
                    streak: streak,
                    nextEntry: entries.first { $0.status == .upcoming || $0.status == .due }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            banners(now: now)

            ForEach(DayPeriod.allCases) { period in
                let periodEntries = entries.filter { DayPeriod($0.dose.scheduledDate) == period }
                if !periodEntries.isEmpty {
                    Section {
                        ForEach(periodEntries) { entry in
                            doseRow(entry)
                        }
                    } header: {
                        Label(period.title, systemImage: period.symbolName)
                    }
                }
            }

            AsNeededSection(medications: activeMedications.filter(\.schedule.isAsNeeded)) { medication in
                actions.logAsNeeded(medication, quantity: medication.schedule.times.first?.quantity ?? 1)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .sensoryFeedback(trigger: taken) { old, new in
            new > old ? .success : .impact(weight: .light)
        }
        .onChange(of: taken) { old, new in
            if new > old, new == entries.count, new > 0 {
                withAnimation(.spring) { isCelebrating = true }
            }
        }
    }

    private func doseRow(_ entry: DoseEntry) -> some View {
        DoseRow(entry: entry) { toggle(entry) }
            .swipeActions(edge: .leading) {
                if entry.status == .taken {
                    Button("Undo", systemImage: "arrow.uturn.backward") { toggle(entry) }
                        .tint(.gray)
                } else {
                    Button("Take", systemImage: "checkmark") { toggle(entry) }
                        .tint(.green)
                }
            }
            .swipeActions(edge: .trailing) {
                if entry.status != .skipped {
                    Button("Skip", systemImage: "forward.fill") {
                        actions.skip(entry.medication, scheduledDate: entry.dose.scheduledDate)
                    }
                    .tint(.orange)
                }
            }
            .contextMenu {
                if entry.status != .taken {
                    Button("Take Now", systemImage: "checkmark.circle") { toggle(entry) }
                    Button("Took It Earlier…", systemImage: "clock.arrow.circlepath") { backdatingEntry = entry }
                }
                if entry.status != .skipped {
                    Button("Skip", systemImage: "forward") {
                        actions.skip(entry.medication, scheduledDate: entry.dose.scheduledDate)
                    }
                }
                if let log = entry.log {
                    Button("Clear", systemImage: "arrow.uturn.backward") { actions.undo(log) }
                }
                Divider()
                Button("Edit \(entry.medication.name)", systemImage: "pencil") {
                    router.editor = .edit(entry.medication)
                }
            }
    }

    @ViewBuilder
    private func banners(now: Date) -> some View {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayKey = yesterday.formatted(.iso8601.year().month().day())
        let missed = DoseTimeline.entries(for: activeMedications, on: yesterday, now: now)
            .filter { $0.status == .missed }
        let missedNames = Array(Set(missed.map(\.medication.name))).sorted()
        let lowSupply = activeMedications.filter(\.isLowOnSupply)

        if !missedNames.isEmpty && dismissedMissedBannerDay != yesterdayKey {
            Section {
                BannerRow(
                    symbolName: "exclamationmark.bubble.fill",
                    color: .orange,
                    title: "Missed yesterday: \(missedNames.formatted(.list(type: .and)))",
                    message: "Today's a fresh start — you've got this."
                ) {
                    Button("Dismiss", systemImage: "xmark") {
                        withAnimation { dismissedMissedBannerDay = yesterdayKey }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        }

        if !lowSupply.isEmpty {
            Section {
                ForEach(lowSupply) { medication in
                    BannerRow(
                        symbolName: "exclamationmark.triangle.fill",
                        color: .red,
                        title: "\(medication.name) is running low",
                        message: lowSupplyMessage(medication)
                    ) {
                        Button("Refilled") { actions.refill(medication) }
                            .buttonStyle(.glass)
                            .sensoryFeedback(.success, trigger: medication.pillsRemaining)
                    }
                }
            }
        }
    }

    private func lowSupplyMessage(_ medication: Medication) -> String {
        var message = "\(medication.pillsRemaining) \(medication.form.unitName(for: medication.pillsRemaining)) left"
        if let days = medication.daysOfSupplyLeft { message += " · about \(days) day\(days == 1 ? "" : "s")" }
        return message
    }

    private func toggle(_ entry: DoseEntry) {
        if entry.status == .taken, let log = entry.log {
            actions.undo(log)
        } else {
            actions.markTaken(entry.medication, scheduledDate: entry.dose.scheduledDate)
        }
    }
}

/// An icon, a title and message, and a trailing accessory.
struct BannerRow<Accessory: View>: View {
    let symbolName: String
    let color: Color
    let title: String
    let message: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.vertical, 4)
    }
}

/// Logs a dose at a time other than now.
private struct BackdateDoseSheet: View {
    let entry: DoseEntry
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(entry: DoseEntry, onSave: @escaping (Date) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _date = State(initialValue: min(entry.dose.scheduledDate, .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Taken at", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            }
            .navigationTitle(entry.medication.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) {
                        onSave(date)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// Medications taken only when needed, with a quick "Log" button.
private struct AsNeededSection: View {
    let medications: [Medication]
    let onLog: (Medication) -> Void

    var body: some View {
        if !medications.isEmpty {
            Section {
                ForEach(medications) { medication in
                    HStack(spacing: 14) {
                        MedIcon(medication)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(medication.name).font(.headline)
                            Text(lastTaken(medication))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Log") { onLog(medication) }
                            .buttonStyle(.borderedProminent)
                            .tint(medication.color.color)
                            .accessibilityLabel("Log a dose of \(medication.name)")
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Label("As Needed", systemImage: "hand.tap.fill")
            }
        }
    }

    private func lastTaken(_ medication: Medication) -> String {
        let last = (medication.doses ?? [])
            .filter { $0.status == .taken }
            .map(\.loggedAt)
            .max()
        guard let last else { return "Not taken yet" }
        return "Last taken \(last.formatted(.relative(presentation: .named)))"
    }
}
