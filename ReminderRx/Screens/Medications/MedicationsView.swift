//
//  MedicationsView.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftData
import SwiftUI

struct MedicationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var searchText = ""
    @State private var pendingDelete: Medication?
    @State private var refillCount = 0

    private var actions: DoseActions { DoseActions(context: modelContext) }

    private var filtered: [Medication] {
        guard !searchText.isEmpty else { return medications }
        return medications.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                let active = filtered.filter { !$0.isArchived }
                let archived = filtered.filter(\.isArchived)

                Section {
                    ForEach(active) { medication in
                        row(medication)
                    }
                }

                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { medication in
                            row(medication)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandBackground())
            .overlay {
                if medications.isEmpty {
                    ContentUnavailableView {
                        Label("No medications yet", systemImage: "cross.vial.fill")
                    } description: {
                        Text("Everything you take — prescriptions, vitamins, as-needed meds — lives here.")
                    } actions: {
                        Button("Add Medication") { router.editor = .new }
                            .buttonStyle(.glassProminent)
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search medications")
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { router.isShowingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Medication", systemImage: "plus") { router.editor = .new }
                }
            }
            .sensoryFeedback(.success, trigger: refillCount)
            .confirmationDialog(
                "Delete \(pendingDelete?.name ?? "")?",
                isPresented: Binding { pendingDelete != nil } set: { if !$0 { pendingDelete = nil } },
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { medication in
                Button("Delete", role: .destructive) {
                    modelContext.delete(medication)
                    actions.commit()
                }
            } message: { _ in
                Text("This also deletes its dose history. Archive it instead to keep the history.")
            }
        }
    }

    private func row(_ medication: Medication) -> some View {
        Button {
            router.editor = .edit(medication)
        } label: {
            MedicationCard(medication: medication)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            if medication.tracksSupply {
                Button("Refill", systemImage: "arrow.clockwise") {
                    actions.refill(medication)
                    refillCount += 1
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDelete = medication
            }
            Button(medication.isArchived ? "Restore" : "Archive", systemImage: "archivebox") {
                medication.archivedAt = medication.isArchived ? nil : .now
                actions.commit()
            }
            .tint(.indigo)
        }
    }
}

struct MedicationCard: View {
    let medication: Medication

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                MedIcon(medication, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(medication.name)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(medication.schedule.summary, systemImage: reminderSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            if medication.tracksSupply {
                SupplyBar(medication: medication)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .opacity(medication.isArchived ? 0.6 : 1)
    }

    private var subtitle: String {
        [medication.dosage, medication.form.displayName]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var reminderSymbol: String {
        medication.remindersEnabled && !medication.schedule.isAsNeeded ? "bell.fill" : "bell.slash"
    }
}
