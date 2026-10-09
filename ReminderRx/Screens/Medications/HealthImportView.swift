//
//  HealthImportView.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftData
import SwiftUI

struct HealthImportView: View {
    private enum LoadState {
        case loading
        case loaded([HealthMedication])
        case failed(String)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [Medication]
    @State private var state = LoadState.loading
    @State private var selection = Set<HealthMedication.ID>()

    private let service = HealthImportService()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import from Health")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(selection.isEmpty ? "Add" : "Add \(selection.count)", role: .confirm) { importSelected() }
                            .disabled(selection.isEmpty)
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Checking Health…")
        case .failed(let message):
            ContentUnavailableView("Couldn't read Health", systemImage: "heart.slash", description: Text(message))
        case .loaded(let medications) where medications.isEmpty:
            ContentUnavailableView(
                "No medications shared",
                systemImage: "heart.text.square",
                description: Text("Add medications in the Health app, then choose which ones Script Tracker can see.")
            )
        case .loaded(let medications):
            List(medications, selection: $selection) { medication in
                HStack(spacing: 12) {
                    Image(systemName: medication.form.symbolName)
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading) {
                        Text(medication.name)
                        if isAlreadyAdded(medication) {
                            Text("Already in Script Tracker").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .safeAreaInset(edge: .bottom) {
                Text("Imported medications start as “as needed”. Open each one to set when you take it and turn on reminders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
    }

    private func load() async {
        guard service.isAvailable else {
            state = .failed("Health isn't available on this device.")
            return
        }
        do {
            let medications = try await service.fetchMedications()
            selection = Set(medications.filter { !isAlreadyAdded($0) }.map(\.id))
            state = .loaded(medications)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func isAlreadyAdded(_ medication: HealthMedication) -> Bool {
        existing.contains { $0.name.localizedCaseInsensitiveCompare(medication.name) == .orderedSame }
    }

    private func importSelected() {
        guard case .loaded(let medications) = state else { return }
        for (offset, medication) in medications.filter({ selection.contains($0.id) }).enumerated() {
            modelContext.insert(Medication(
                name: medication.name,
                form: medication.form,
                color: .cycling(existing.count + offset),
                schedule: Schedule(frequency: .asNeeded, times: [DoseTime(hour: 9, minute: 0)]),
                remindersEnabled: false,
                tracksSupply: false
            ))
        }
        DoseActions(context: modelContext).commit()
        dismiss()
    }
}
