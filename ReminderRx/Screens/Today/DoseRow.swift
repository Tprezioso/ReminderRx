//
//  DoseRow.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftUI

/// One scheduled dose on Today, with a big check button to take or undo it.
struct DoseRow: View {
    let entry: DoseEntry
    let onToggle: () -> Void

    private var medication: Medication { entry.medication }
    private var isTaken: Bool { entry.status == .taken }

    var body: some View {
        HStack(spacing: 14) {
            MedIcon(medication)

            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.headline)
                    .strikethrough(entry.status == .skipped)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let pill = statusPill {
                    pill
                }
            }

            Spacer(minLength: 8)

            Button(action: onToggle) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(isTaken ? AnyShapeStyle(medication.color.color) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isTaken)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTaken ? "Undo \(medication.name)" : "Take \(medication.name)")
        }
        .padding(.vertical, 6)
        .opacity(entry.status == .skipped ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        var parts = [entry.dose.scheduledDate.formatted(date: .omitted, time: .shortened)]
        parts.append("\(entry.dose.quantity) \(medication.form.unitName(for: entry.dose.quantity))")
        if !medication.dosage.isEmpty { parts.append(medication.dosage) }
        return parts.joined(separator: " · ")
    }

    private var statusPill: StatusPill? {
        switch entry.status {
        case .taken:
            let time = entry.log?.loggedAt.formatted(date: .omitted, time: .shortened) ?? ""
            return StatusPill(text: "Taken \(time)", color: .green)
        case .skipped:
            return StatusPill(text: "Skipped", color: .secondary)
        case .missed:
            return StatusPill(text: "Missed", color: .red)
        case .due:
            return StatusPill(text: "Due now", color: .orange)
        case .upcoming:
            return nil
        }
    }
}
