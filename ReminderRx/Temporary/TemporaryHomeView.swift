//
//  TemporaryHomeView.swift
//  ReminderRx
//
//  Bare-bones screen for checking the Phase 1 data layer. Replaced by the new UI in Phase 3.
//

import ReminderRxKit
import SwiftData
import SwiftUI

struct TemporaryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.name) private var medications: [Medication]

    private var actions: DoseActions { DoseActions(context: modelContext) }

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    ForEach(DoseTimeline.entries(for: medications, on: .now)) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.medication.name)
                                Text(entry.dose.scheduledDate, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(describing: entry.status))
                                .font(.caption)
                            Button(entry.status == .taken ? "Undo" : "Take") {
                                if let log = entry.log, entry.status == .taken {
                                    actions.undo(log)
                                } else {
                                    actions.markTaken(entry.medication, scheduledDate: entry.dose.scheduledDate)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Medications") {
                    ForEach(medications) { medication in
                        VStack(alignment: .leading) {
                            Text(medication.name).font(.headline)
                            Text("\(medication.pillsRemaining) left · \(medication.refillsRemaining) refills · reminders \(medication.remindersEnabled ? "on" : "off")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Refill") { actions.refill(medication) }
                                .tint(.green)
                        }
                    }
                }
            }
            .navigationTitle("ReminderRx")
            .toolbar {
                #if DEBUG
                Button("Add Sample", systemImage: "plus") {
                    let medication = Medication(
                        name: "Sample \(medications.count + 1)",
                        dosage: "10 mg",
                        color: .cycling(medications.count),
                        schedule: Schedule(frequency: .daily, times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)]),
                        pillsRemaining: 30
                    )
                    modelContext.insert(medication)
                    actions.commit()
                }
                #endif
            }
        }
    }
}

#Preview {
    TemporaryHomeView()
        .modelContainer(try! SharedStore.makeContainer(inMemory: true))
}
