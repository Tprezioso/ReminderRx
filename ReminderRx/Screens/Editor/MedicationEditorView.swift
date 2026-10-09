//
//  MedicationEditorView.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftData
import SwiftUI

struct MedicationEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService
    @State private var model: MedicationEditorModel
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFocused: Bool

    init(model: MedicationEditorModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Form {
                heroSection
                detailsSection
                appearanceSection
                ScheduleSection(model: model)
                remindersSection
                supplySection
                Section("Notes") {
                    TextField("Instructions, prescriber, pharmacy…", text: $model.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                if let medication = model.medication {
                    manageSection(medication)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(model.isNew ? "New Medication" : "Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) {
                        model.save(in: modelContext)
                        dismiss()
                    }
                    .disabled(!model.isValid)
                }
            }
            .onAppear {
                if model.isNew { isNameFocused = true }
            }
        }
    }

    private var heroSection: some View {
        Section {
            VStack(spacing: 14) {
                MedIcon(symbolName: model.symbolName, color: model.color, size: 84)
                    .animation(.spring, value: model.color)
                    .contentTransition(.symbolEffect(.replace))
                TextField("Medication name", text: $model.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .focused($isNameFocused)
                    .submitLabel(.next)
                    .textInputAutocapitalization(.words)
                if let message = model.validationMessage, !model.name.isEmpty || !model.isNew {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Strength, e.g. 10 mg", text: $model.dosage)
            Picker("Form", selection: $model.form) {
                ForEach(MedicationForm.allCases) { form in
                    Label(form.displayName, systemImage: form.symbolName).tag(form)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            HStack {
                ForEach(MedColor.allCases) { color in
                    Button {
                        model.color = color
                    } label: {
                        Circle()
                            .fill(color.gradient)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if model.color == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(color.rawValue.capitalized)
                    .accessibilityAddTraits(model.color == color ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: model.color)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                ForEach(MedicationEditorModel.symbolChoices, id: \.self) { symbol in
                    Button {
                        model.symbolName = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.body)
                            .frame(width: 34, height: 34)
                            .foregroundStyle(model.symbolName == symbol ? .white : .primary)
                            .background(
                                model.symbolName == symbol ? AnyShapeStyle(model.color.gradient) : AnyShapeStyle(.quaternary),
                                in: .rect(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.symbolName == symbol ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
            .sensoryFeedback(.selection, trigger: model.symbolName)
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        if model.frequency != .asNeeded {
            Section {
                Toggle("Remind me", isOn: $model.remindersEnabled)
                if model.remindersEnabled && notificationService.authorizationStatus == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notifications are turned off for Script Tracker.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") { notificationService.openSystemSettings() }
                            .font(.footnote.weight(.semibold))
                    }
                }
            } footer: {
                Text("Reminders have Taken, Snooze and Skip buttons, so you can log a dose without opening the app.")
            }
        }
    }

    private var supplySection: some View {
        Section {
            Toggle("Track supply", isOn: $model.tracksSupply.animation())
            if model.tracksSupply {
                NumberRow(title: "On hand", value: $model.pillsRemaining)
                NumberRow(title: "Amount per refill", value: $model.quantityPerFill)
                NumberRow(title: "Refills left", value: $model.refillsRemaining)
                NumberRow(title: "Warn me at", value: $model.lowSupplyThreshold)
            }
        } header: {
            Text("Supply")
        } footer: {
            if model.tracksSupply {
                Text("You'll get a refill reminder when you're down to \(model.lowSupplyThreshold) \(model.form.unitName(for: model.lowSupplyThreshold)).")
            }
        }
    }

    private func manageSection(_ medication: Medication) -> some View {
        Section {
            Button(medication.isArchived ? "Restore Medication" : "Archive Medication", systemImage: "archivebox") {
                medication.archivedAt = medication.isArchived ? nil : .now
                DoseActions(context: modelContext).commit()
                dismiss()
            }
            Button("Delete Medication", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
            .confirmationDialog("Delete \(medication.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(medication)
                    DoseActions(context: modelContext).commit()
                    dismiss()
                }
            } message: {
                Text("This also deletes its dose history. Archive it instead to keep the history.")
            }
        } footer: {
            Text("Archived medications stop reminding you but keep their history.")
        }
    }
}

/// Days, times and quantities.
private struct ScheduleSection: View {
    @Bindable var model: MedicationEditorModel

    var body: some View {
        Section {
            Picker("Frequency", selection: $model.frequency.animation()) {
                ForEach(MedicationEditorModel.FrequencyKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            switch model.frequency {
            case .weekdays:
                WeekdayPicker(selection: $model.weekdays, tint: model.color.color)
            case .interval:
                Stepper("Every \(model.interval) days", value: $model.interval, in: 2...30)
                DatePicker("Starting", selection: $model.intervalStart, displayedComponents: .date)
            case .daily, .asNeeded:
                EmptyView()
            }

            if model.frequency == .asNeeded {
                if let index = model.times.indices.first {
                    Stepper("\(model.times[index].quantity) \(model.form.unitName(for: model.times[index].quantity)) per dose",
                            value: $model.times[index].quantity, in: 1...20)
                }
            } else {
                ForEach($model.times) { $time in
                    HStack {
                        DatePicker("Time", selection: timeBinding($time), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Spacer()
                        Stepper("\(time.quantity) \(model.form.unitName(for: time.quantity))", value: $time.quantity, in: 1...20)
                            .fixedSize()
                    }
                }
                .onDelete { model.times.remove(atOffsets: $0) }

                Button("Add a Time", systemImage: "plus.circle.fill") {
                    withAnimation { model.addTime() }
                }
            }
        } header: {
            Text("Schedule")
        }
    }

    private func timeBinding(_ time: Binding<DoseTime>) -> Binding<Date> {
        Binding {
            time.wrappedValue.date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            time.wrappedValue.hour = parts.hour ?? 9
            time.wrappedValue.minute = parts.minute ?? 0
        }
    }
}

/// S M T W T F S toggle chips, ordered by the locale's first weekday.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    let tint: Color

    private var weekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(isOn ? .white : .primary)
                        .background(isOn ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.quaternary), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct NumberRow: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        LabeledContent(title) {
            TextField(title, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }
}
