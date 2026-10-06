//
//  MedicationForm.swift
//  ReminderRxKit
//

import Foundation

public enum MedicationForm: String, Codable, CaseIterable, Identifiable, Sendable {
    case tablet, capsule, liquid, injection, inhaler, drops, cream, other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tablet: "Tablet"
        case .capsule: "Capsule"
        case .liquid: "Liquid"
        case .injection: "Injection"
        case .inhaler: "Inhaler"
        case .drops: "Drops"
        case .cream: "Cream"
        case .other: "Other"
        }
    }

    public var symbolName: String {
        switch self {
        case .tablet: "pills.fill"
        case .capsule: "capsule.fill"
        case .liquid: "drop.fill"
        case .injection: "syringe.fill"
        case .inhaler: "lungs.fill"
        case .drops: "eyedropper.halffull"
        case .cream: "hand.raised.fill"
        case .other: "cross.vial.fill"
        }
    }

    /// The word for one unit of supply, e.g. "2 capsules", "5 mL".
    public func unitName(for quantity: Int) -> String {
        let singular: String
        switch self {
        case .tablet: singular = "tablet"
        case .capsule: singular = "capsule"
        case .liquid: return "mL"
        case .injection: singular = "dose"
        case .inhaler: singular = "puff"
        case .drops: singular = "drop"
        case .cream: singular = "application"
        case .other: singular = "dose"
        }
        return quantity == 1 ? singular : singular + "s"
    }
}
