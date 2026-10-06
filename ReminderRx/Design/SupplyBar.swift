//
//  SupplyBar.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftUI

/// How much of a fill is left, turning red when supply is low.
struct SupplyBar: View {
    let medication: Medication

    private var fraction: Double {
        guard medication.quantityPerFill > 0 else { return 0 }
        return min(Double(medication.pillsRemaining) / Double(medication.quantityPerFill), 1)
    }

    private var tint: Color {
        medication.isLowOnSupply ? .red : medication.color.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 8 : 0))
                }
            }
            .frame(height: 8)
            .animation(.spring, value: fraction)

            HStack(spacing: 4) {
                if medication.isLowOnSupply {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                Text(description)
            }
            .font(.caption)
            .foregroundStyle(medication.isLowOnSupply ? .red : .secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var description: String {
        let unit = medication.form.unitName(for: medication.pillsRemaining)
        var text = "\(medication.pillsRemaining) \(unit) left"
        if let days = medication.daysOfSupplyLeft {
            text += days == 1 ? " · about 1 day" : " · about \(days) days"
        }
        if medication.refillsRemaining > 0 {
            text += " · \(medication.refillsRemaining) refill\(medication.refillsRemaining == 1 ? "" : "s")"
        }
        return text
    }
}
