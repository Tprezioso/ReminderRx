//
//  PrescriptionCellButton.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/12/21.
//

import SwiftUI

struct PrescriptionCellButton: View {
    @StateObject var prescription: Prescriptions
    
    var body: some View {
        HStack(spacing: 0) {
            PrescriptionProgressView(prescription: prescription)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "pills.circle")
                        .imageScale(.large)
                    Text("Name: \(prescription.name ?? "")")
                        .lineLimit(2)
                }
                
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .imageScale(.large)
                    Text("Refill: \(prescription.refills ?? "")")
                }
            }
            Spacer()
            prescription.isOn ? Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green) : Image(systemName: "circle").font(.title2).foregroundColor(.green)
        }
    }
}

struct PrescriptionCellButton_Previews: PreviewProvider {
    static var previews: some View {
        PrescriptionCellButton(prescription: Prescriptions())
    }
}
