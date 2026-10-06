//
//  MedIcon.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftUI

/// A medication's colored symbol badge.
struct MedIcon: View {
    let symbolName: String
    let color: MedColor
    var size: CGFloat = 44

    init(symbolName: String, color: MedColor, size: CGFloat = 44) {
        self.symbolName = symbolName
        self.color = color
        self.size = size
    }

    init(_ medication: Medication, size: CGFloat = 44) {
        self.init(symbolName: medication.symbolName, color: medication.color, size: size)
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.3))
            .shadow(color: color.color.opacity(0.35), radius: size * 0.12, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(MedColor.allCases) { color in
            MedIcon(symbolName: "pills.fill", color: color)
        }
    }
}
