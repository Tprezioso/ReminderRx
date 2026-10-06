//
//  HistoryView.swift
//  ReminderRx
//

import Charts
import ReminderRxKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    enum Range: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30

        var id: Self { self }
        var title: String { self == .week ? "7 Days" : "30 Days" }
    }

    @Environment(AppRouter.self) private var router
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \DoseLog.loggedAt, order: .reverse) private var logs: [DoseLog]
    @State private var range: Range = .week
    @State private var medicationFilter: UUID?

    private var calculator: AdherenceCalculator { AdherenceCalculator() }

    private var filteredMedications: [Medication] {
        guard let medicationFilter else { return medications }
        return medications.filter { $0.id == medicationFilter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if medications.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Once you start logging doses, your streaks and adherence show up here.")
                    )
                } else {
                    content(now: .now)
                }
            }
            .background(BrandBackground())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { router.isShowingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    filterMenu
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Medication", selection: $medicationFilter) {
                Text("All Medications").tag(UUID?.none)
                ForEach(medications) { medication in
                    Text(medication.name).tag(UUID?.some(medication.id))
                }
            }
        } label: {
            Label("Filter", systemImage: medicationFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func content(now: Date) -> some View {
        let snapshots = filteredMedications.map(\.snapshot)
        let ids = Set(filteredMedications.map(\.id))
        let logSnapshots = logs.compactMap(\.snapshot).filter { ids.contains($0.medicationID) }
        let days = calculator.lastDays(range.rawValue, medications: snapshots, logs: logSnapshots, now: now)
        let rate = calculator.rate(lastDays: range.rawValue, medications: snapshots, logs: logSnapshots, now: now)

        return List {
            Section {
                Picker("Range", selection: $range.animation()) {
                    ForEach(Range.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                HStack(spacing: 12) {
                    StatTile(
                        value: "\(calculator.currentStreak(medications: snapshots, logs: logSnapshots, now: now))",
                        unit: "days",
                        title: "Current streak",
                        symbolName: "flame.fill",
                        tint: .orange
                    )
                    StatTile(
                        value: "\(calculator.bestStreak(medications: snapshots, logs: logSnapshots, now: now))",
                        unit: "days",
                        title: "Best streak",
                        symbolName: "trophy.fill",
                        tint: .yellow
                    )
                    StatTile(
                        value: rate.map { "\(Int(($0 * 100).rounded()))" } ?? "–",
                        unit: rate == nil ? "" : "%",
                        title: "Doses taken",
                        symbolName: "checkmark.seal.fill",
                        tint: .accentColor
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                AdherenceChart(days: days, range: range)
            } header: {
                Text("Daily adherence")
            } footer: {
                Text("Share of scheduled doses taken each day. Tap a bar for details.")
            }

            DoseLogSections(
                medications: filteredMedications,
                logs: logs.filter { $0.medication.map { ids.contains($0.id) } ?? false },
                days: range.rawValue,
                now: now
            )
        }
        .scrollContentBackground(.hidden)
    }
}

private struct StatTile: View {
    let value: String
    let unit: String
    let title: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title.bold())
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

private struct AdherenceChart: View {
    let days: [DayAdherence]
    let range: HistoryView.Range
    @State private var selectedDate: Date?

    private var selectedDay: DayAdherence? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }

    var body: some View {
        Chart {
            ForEach(days) { day in
                if let rate = day.rate {
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Taken", rate * 100),
                        width: .ratio(range == .week ? 0.5 : 0.7)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.accentColor.gradient)
                    .opacity(selectedDay == nil || selectedDay?.day == day.day ? 1 : 0.35)
                    .accessibilityLabel(day.day.formatted(.dateTime.weekday(.wide).month().day()))
                    .accessibilityValue("\(day.taken) of \(day.scheduled) doses taken")
                }
            }

            if let selectedDay {
                RuleMark(x: .value("Selected", selectedDay.day, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(for: selectedDay)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let percent = value.as(Int.self) { Text("\(percent)%") }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                AxisValueLabel(format: range == .week ? .dateTime.weekday(.narrow) : .dateTime.month(.abbreviated).day(), centered: true)
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private var xDomain: ClosedRange<Date> {
        let first = days.first?.day ?? .now
        let last = Calendar.current.date(byAdding: .day, value: 1, to: days.last?.day ?? .now) ?? .now
        return first...last
    }

    private func tooltip(for day: DayAdherence) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.day.formatted(.dateTime.weekday(.abbreviated).month().day()))
                .font(.caption.weight(.semibold))
            if day.scheduled == 0 {
                Text("Nothing scheduled").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("\(day.taken) of \(day.scheduled) taken").font(.caption2)
                if day.skipped > 0 {
                    Text("\(day.skipped) skipped").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}

/// Day-by-day log of taken, skipped and missed doses.
private struct DoseLogSections: View {
    struct Item: Identifiable {
        enum Kind { case taken, skipped, missed, asNeeded }

        let id: String
        let medication: Medication
        let kind: Kind
        let time: Date
        let scheduledDate: Date?
    }

    let medications: [Medication]
    let logs: [DoseLog]
    let days: Int
    let now: Date

    var body: some View {
        let groups = groupedItems()
        if groups.isEmpty {
            Section {
                Text("No doses logged in this period.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(groups, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.wide).month().day())) {
                    ForEach(group.items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 12) {
            MedIcon(item.medication, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.medication.name).font(.subheadline.weight(.semibold))
                Text(detail(item)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(label(item.kind), systemImage: symbol(item.kind))
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(item.kind))
        }
        .accessibilityElement(children: .combine)
    }

    private func groupedItems() -> [(day: Date, items: [Item])] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now

        var items: [Item] = logs.compactMap { log in
            guard let medication = log.medication else { return nil }
            let anchor = log.scheduledDate ?? log.loggedAt
            guard anchor >= start else { return nil }
            let kind: Item.Kind = log.scheduledDate == nil ? .asNeeded : (log.status == .taken ? .taken : .skipped)
            return Item(id: log.id.uuidString, medication: medication, kind: kind, time: log.loggedAt, scheduledDate: log.scheduledDate)
        }

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            for entry in DoseTimeline.entries(for: medications, on: day, now: now) where entry.status == .missed {
                items.append(Item(id: entry.id, medication: entry.medication, kind: .missed, time: entry.dose.scheduledDate, scheduledDate: entry.dose.scheduledDate))
            }
        }

        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.scheduledDate ?? $0.time) }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { ($0.scheduledDate ?? $0.time) > ($1.scheduledDate ?? $1.time) }) }
            .sorted { $0.day > $1.day }
    }

    private func detail(_ item: Item) -> String {
        let time = item.time.formatted(date: .omitted, time: .shortened)
        switch item.kind {
        case .taken:
            let scheduled = item.scheduledDate?.formatted(date: .omitted, time: .shortened) ?? time
            return scheduled == time ? "At \(time)" : "At \(time) · due \(scheduled)"
        case .skipped: return "Due \(item.scheduledDate?.formatted(date: .omitted, time: .shortened) ?? time)"
        case .missed: return "Due \(time)"
        case .asNeeded: return "As needed · \(time)"
        }
    }

    private func label(_ kind: Item.Kind) -> String {
        switch kind {
        case .taken, .asNeeded: "Taken"
        case .skipped: "Skipped"
        case .missed: "Missed"
        }
    }

    private func symbol(_ kind: Item.Kind) -> String {
        switch kind {
        case .taken, .asNeeded: "checkmark.circle.fill"
        case .skipped: "forward.circle.fill"
        case .missed: "xmark.circle.fill"
        }
    }

    private func color(_ kind: Item.Kind) -> Color {
        switch kind {
        case .taken, .asNeeded: .green
        case .skipped: .secondary
        case .missed: .red
        }
    }
}
