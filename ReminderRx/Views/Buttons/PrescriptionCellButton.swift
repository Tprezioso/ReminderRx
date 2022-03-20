//
//  PrescriptionCellButton.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/12/21.
//

import SwiftUI

struct PrescriptionCellButton: View {
    @ObservedObject var prescription: Prescriptions
    
    var body: some View {
        HStack {
//            VStack {
//                Text("Count")
//                Text(prescription.count ?? "")
//            }
//            .frame(height: 100)
//            .font(.title.weight(.thin))
            CustomProgressView(progress: Binding($prescription.count, ""))
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "pills.circle")
                    Text("Name: \(prescription.name ?? "")")
                }
                
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
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
