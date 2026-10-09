//
//  ReminderRxWidgets.swift
//  ReminderRxWidgets
//

import AppIntents
import ReminderRxKit
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct NextDoseConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Next Dose"
    static let description = IntentDescription("Shows your next dose. Pick a medication, or leave it empty to show all of them.")

    @Parameter(title: "Medication")
    var medication: MedicationEntity?
}

// MARK: - Entry

struct WidgetDose: Hashable, Identifiable {
    let medicationID: UUID
    let name: String
    let dosage: String
    let symbolName: String
    let color: MedColor
    let scheduledDate: Date
    let quantityText: String
    let status: DoseStatus

    var id: String { "\(medicationID)-\(scheduledDate.timeIntervalSince1970)" }

    var takeIntent: MarkDoseTakenIntent {
        MarkDoseTakenIntent(medication: MedicationEntity(id: medicationID, name: name, dosage: dosage), scheduledDate: scheduledDate)
    }

    var timeText: String {
        status == .due || status == .missed ? "Due now" : scheduledDate.formatted(date: .omitted, time: .shortened)
    }
}

struct NextDoseEntry: TimelineEntry {
    let date: Date
    let taken: Int
    let total: Int
    /// Today's doses not yet taken or skipped, in time order.
    let remaining: [WidgetDose]
    /// The first dose on a later day, when nothing is left today.
    let later: WidgetDose?
    let hasMedications: Bool

    var progress: Double { total == 0 ? 0 : Double(taken) / Double(total) }
    var isAllDone: Bool { total > 0 && remaining.isEmpty }

    @MainActor
    static func make(at date: Date, medicationID: UUID?) -> NextDoseEntry {
        // A fresh context each time, so changes made in the app are picked up.
        let context = ModelContext(SharedStore.container)
        var medications = DoseLookup.activeMedications(in: context)
        if let medicationID {
            medications = medications.filter { $0.id == medicationID }
        }

        let entries = DoseTimeline.entries(for: medications, on: date, now: date)
        let remaining = entries
            .filter { $0.status != .taken && $0.status != .skipped }
            .map(WidgetDose.make)

        var later: WidgetDose?
        if remaining.isEmpty {
            let tomorrow = Calendar.current.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
            if let dose = DoseScheduler().nextDose(for: medications.map(\.snapshot), after: tomorrow.addingTimeInterval(-1)),
               let medication = medications.first(where: { $0.id == dose.medicationID }) {
                later = WidgetDose.make(medication: medication, dose: dose, status: .upcoming)
            }
        }

        return NextDoseEntry(
            date: date,
            taken: entries.filter { $0.status == .taken }.count,
            total: entries.count,
            remaining: remaining,
            later: later,
            hasMedications: !medications.isEmpty
        )
    }

    static let preview: NextDoseEntry = {
        let now = Date.now
        let doses = [
            ("Lisinopril", "10 mg", "pills.fill", MedColor.blue, 0.0),
            ("Vitamin D", "1000 IU", "sun.max.fill", MedColor.orange, 3600.0),
            ("Atorvastatin", "20 mg", "heart.fill", MedColor.pink, 7200.0),
        ].map { name, dosage, symbol, color, offset in
            WidgetDose(medicationID: UUID(), name: name, dosage: dosage, symbolName: symbol, color: color,
                       scheduledDate: now.addingTimeInterval(offset), quantityText: "1 tablet", status: offset == 0 ? .due : .upcoming)
        }
        return NextDoseEntry(date: now, taken: 2, total: 5, remaining: doses, later: nil, hasMedications: true)
    }()
}

extension WidgetDose {
    // Factories rather than delegating initializers, which Xcode previews can't compile.
    @MainActor
    static func make(_ entry: DoseEntry) -> WidgetDose {
        make(medication: entry.medication, dose: entry.dose, status: entry.status)
    }

    @MainActor
    static func make(medication: Medication, dose: ScheduledDose, status: DoseStatus) -> WidgetDose {
        WidgetDose(
            medicationID: medication.id,
            name: medication.name,
            dosage: medication.dosage,
            symbolName: medication.symbolName,
            color: medication.color,
            scheduledDate: dose.scheduledDate,
            quantityText: "\(dose.quantity) \(medication.form.unitName(for: dose.quantity))",
            status: status
        )
    }
}

// MARK: - Provider

struct NextDoseProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NextDoseEntry {
        .preview
    }

    func snapshot(for configuration: NextDoseConfigurationIntent, in context: Context) async -> NextDoseEntry {
        if context.isPreview { return .preview }
        return await NextDoseEntry.make(at: .now, medicationID: configuration.medication?.id)
    }

    func timeline(for configuration: NextDoseConfigurationIntent, in context: Context) async -> Timeline<NextDoseEntry> {
        let now = Date.now
        let medicationID = configuration.medication?.id
        let first = await NextDoseEntry.make(at: now, medicationID: medicationID)

        // Refresh as each dose comes due, when it turns into "missed", and at midnight.
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let changeDates = first.remaining
            .flatMap { [$0.scheduledDate, $0.scheduledDate.addingTimeInterval(DoseTimeline.dueWindow)] }
            .filter { $0 > now && $0 < midnight }
        var entries = [first]
        for date in Set(changeDates + [midnight]).sorted().prefix(20) {
            entries.append(await NextDoseEntry.make(at: date, medicationID: medicationID))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Widget

struct NextDoseWidget: Widget {
    static let kind = "NextDoseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NextDoseConfigurationIntent.self, provider: NextDoseProvider()) { entry in
            NextDoseWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.18), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Next Dose")
        .description("See what's next and log it with a tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct NextDoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextDoseEntry

    var body: some View {
        switch family {
        case .systemMedium: MediumView(entry: entry)
        case .accessoryCircular: CircularView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline: InlineView(entry: entry)
        default: SmallView(entry: entry)
        }
    }
}

// MARK: - Home Screen

private struct SmallView: View {
    let entry: NextDoseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MiniRing(progress: entry.progress)
                    .frame(width: 30, height: 30)
                Text("\(entry.taken)/\(entry.total)")
                    .font(.subheadline.bold())
                    .contentTransition(.numericText())
                Spacer()
            }

            Spacer(minLength: 0)

            if let dose = entry.remaining.first {
                HStack(spacing: 8) {
                    WidgetMedIcon(symbolName: dose.symbolName, color: dose.color, size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dose.name).font(.headline).lineLimit(1)
                        Text(dose.timeText)
                            .font(.caption)
                            .foregroundStyle(dose.status == .upcoming ? .secondary : Color.orange)
                    }
                }
                Button(intent: dose.takeIntent) {
                    Label("Take", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(dose.color.color)
            } else {
                StatusMessage(entry: entry)
            }
        }
    }
}

private struct MediumView: View {
    let entry: NextDoseEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                ZStack {
                    MiniRing(progress: entry.progress, lineWidth: 9)
                    Text("\(entry.taken)/\(entry.total)")
                        .font(.title3.bold())
                        .contentTransition(.numericText())
                }
                .frame(width: 78, height: 78)
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                if entry.remaining.isEmpty {
                    StatusMessage(entry: entry)
                } else {
                    ForEach(entry.remaining.prefix(3)) { dose in
                        HStack(spacing: 8) {
                            WidgetMedIcon(symbolName: dose.symbolName, color: dose.color, size: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(dose.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text("\(dose.timeText) · \(dose.quantityText)")
                                    .font(.caption2)
                                    .foregroundStyle(dose.status == .upcoming ? .secondary : Color.orange)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Button(intent: dose.takeIntent) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(dose.color.color)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Take \(dose.name)")
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct StatusMessage: View {
    let entry: NextDoseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entry.hasMedications {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.tint)
                Text("Add a medication in Script Tracker").font(.caption).foregroundStyle(.secondary)
            } else if entry.isAllDone {
                Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(.green)
                Text("All done for today!").font(.subheadline.bold())
            } else {
                Image(systemName: "moon.stars.fill").font(.title2).foregroundStyle(.indigo)
                Text("Nothing scheduled today").font(.subheadline.bold())
            }
            if let later = entry.later {
                Text("Next: \(later.name) \(later.scheduledDate.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Lock Screen

private struct CircularView: View {
    let entry: NextDoseEntry

    var body: some View {
        Gauge(value: Double(entry.taken), in: 0...Double(max(entry.total, 1))) {
            Image(systemName: "pills.fill")
        } currentValueLabel: {
            Text("\(entry.taken)/\(entry.total)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

private struct RectangularView: View {
    let entry: NextDoseEntry

    var body: some View {
        if let dose = entry.remaining.first ?? entry.later {
            VStack(alignment: .leading, spacing: 1) {
                Label("Next dose", systemImage: "pills.fill")
                    .font(.caption2)
                    .widgetAccentable()
                Text(dose.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.remaining.isEmpty
                     ? dose.scheduledDate.formatted(.relative(presentation: .named))
                     : "\(dose.timeText) · \(dose.quantityText)")
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label(entry.isAllDone ? "All done for today" : "No doses scheduled", systemImage: "checkmark.seal.fill")
                .font(.headline)
        }
    }
}

private struct InlineView: View {
    let entry: NextDoseEntry

    var body: some View {
        if let dose = entry.remaining.first {
            Label("\(dose.name) · \(dose.timeText)", systemImage: "pills.fill")
        } else {
            Label(entry.isAllDone ? "All doses taken" : "No doses today", systemImage: "checkmark.circle")
        }
    }
}

// MARK: - Pieces

private struct MiniRing: View {
    let progress: Double
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.001))
                .stroke(
                    // End the gradient where the progress ends so it doesn't wrap around.
                    AngularGradient(colors: [.indigo, .purple, .pink, .orange], center: .center, startAngle: .zero, endAngle: .degrees(360 * max(min(progress, 1), 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(progress == 0 ? 0 : 1)
        }
        .widgetAccentable()
    }
}

private struct WidgetMedIcon: View {
    let symbolName: String
    let color: MedColor
    let size: CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.3))
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    NextDoseWidget()
} timeline: {
    NextDoseEntry.preview
}

#Preview(as: .systemMedium) {
    NextDoseWidget()
} timeline: {
    NextDoseEntry.preview
}

#Preview(as: .accessoryRectangular) {
    NextDoseWidget()
} timeline: {
    NextDoseEntry.preview
}
