//
//  MedicationEntity.swift
//  ReminderRxKit
//

import AppIntents
import Foundation
import SwiftData

/// Lets the app and widget extension find the intents defined in this framework.
public struct ReminderRxKitIntents: AppIntentsPackage {}

public struct MedicationEntity: AppEntity, Identifiable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Medication"
    public static let defaultQuery = MedicationQuery()

    public let id: UUID
    public let name: String
    public let dosage: String

    public init(id: UUID, name: String, dosage: String = "") {
        self.id = id
        self.name = name
        self.dosage = dosage
    }

    public init(_ medication: Medication) {
        self.init(id: medication.id, name: medication.name, dosage: medication.dosage)
    }

    public var displayRepresentation: DisplayRepresentation {
        if dosage.isEmpty {
            DisplayRepresentation(title: "\(name)", image: .init(systemName: "pills.fill"))
        } else {
            DisplayRepresentation(title: "\(name)", subtitle: "\(dosage)", image: .init(systemName: "pills.fill"))
        }
    }
}

public struct MedicationQuery: EntityStringQuery {
    public init() {}

    @MainActor
    public func entities(for identifiers: [UUID]) async throws -> [MedicationEntity] {
        let ids = Set(identifiers)
        return medications().filter { ids.contains($0.id) }.map(MedicationEntity.init)
    }

    @MainActor
    public func entities(matching string: String) async throws -> [MedicationEntity] {
        medications().filter { $0.name.localizedStandardContains(string) }.map(MedicationEntity.init)
    }

    @MainActor
    public func suggestedEntities() async throws -> [MedicationEntity] {
        medications().map(MedicationEntity.init)
    }

    @MainActor
    private func medications() -> [Medication] {
        DoseLookup.activeMedications(in: SharedStore.container.mainContext)
    }
}

enum MedicationIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound: "That medication couldn't be found in Script Tracker."
        }
    }
}
