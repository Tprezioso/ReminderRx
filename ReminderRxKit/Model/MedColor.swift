//
//  MedColor.swift
//  ReminderRxKit
//

import SwiftUI

/// The palette a user picks from to color-code a medication.
public enum MedColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, purple, pink, red, orange, yellow, green, teal

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        }
    }

    public var gradient: LinearGradient {
        LinearGradient(colors: [color.mix(with: .white, by: 0.2), color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Cycles through the palette so new or imported medications get distinct colors.
    public static func cycling(_ index: Int) -> MedColor {
        allCases[index % allCases.count]
    }
}
