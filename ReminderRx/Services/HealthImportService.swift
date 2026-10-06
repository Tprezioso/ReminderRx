//
//  HealthImportService.swift
//  ReminderRx
//

import HealthKit
import ReminderRxKit

/// A medication from the Health app, ready to copy into ReminderRx.
struct HealthMedication: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let form: MedicationForm
}

/// Reads the medications the person has added in the Health app. HealthKit only lets other apps
/// read them (and the person picks which ones), so this is a one-way import.
final class HealthImportService {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func fetchMedications() async throws -> [HealthMedication] {
        try await store.requestPerObjectReadAuthorization(for: HKObjectType.userAnnotatedMedicationType(), predicate: nil)
        let medications = try await HKUserAnnotatedMedicationQueryDescriptor().result(for: store)
        return medications
            .filter { !$0.isArchived }
            .map { medication in
                HealthMedication(
                    name: medication.nickname ?? medication.medication.displayText,
                    form: MedicationForm(medication.medication.generalForm)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

extension MedicationForm {
    init(_ healthForm: HKMedicationGeneralForm) {
        switch healthForm {
        case .tablet: self = .tablet
        case .capsule: self = .capsule
        case .liquid: self = .liquid
        case .injection: self = .injection
        case .inhaler, .spray: self = .inhaler
        case .drops: self = .drops
        case .cream, .gel, .lotion, .ointment, .topical, .foam, .patch: self = .cream
        default: self = .other
        }
    }
}
