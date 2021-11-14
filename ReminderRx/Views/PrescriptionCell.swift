//
//  PrescriptionCell.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/12/21.
//

import SwiftUI

struct PrescriptionCell: View {

    var prescription: Prescription
    @State var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
                HStack {
                    VStack {
                        Text("Count")
                        Text("\(prescription.count)")
                    }
                    .frame(height: 100)
                    .font(.title.weight(.thin))
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "pills.circle")
                            Text("Name:\(prescription.name)")
                        }
                        
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                            Text("Refill:")
                        }
                    }
                    Spacer()
                    isOn ? Image(systemName: "checkmark.circle") : Image(systemName: "circle")
                }
        }.toggleStyle(.button)
        
        
    }
}

struct PrescriptionCell_Previews: PreviewProvider {
    static var previews: some View {
        PrescriptionCell(prescription: Prescription(name: "Pills", count: 99), isOn: true)
    }
}
