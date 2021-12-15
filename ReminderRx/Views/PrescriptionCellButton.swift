//
//  PrescriptionCellButton.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/12/21.
//

import SwiftUI

struct PrescriptionCellButton: View {
    var name: String
    var count: Int64
    var refill: Int64
    @State var isOn: Bool
    
    var body: some View {
        Button {
            isOn = true
//            self.count -= 1
        } label: {
            HStack {
                VStack {
                    Text("Count")
                    Text("\(count)")
                }
                .frame(height: 100)
                .font(.title.weight(.thin))
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "pills.circle")
                        Text("Name:\(name)")
                    }
                    
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Refill: \(refill)")
                    }
                }
                Spacer()
                isOn ? Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green) : Image(systemName: "circle").font(.title2).foregroundColor(.green)
            }
        }
    }
}

struct PrescriptionCellButton_Previews: PreviewProvider {
    static var previews: some View {
        PrescriptionCellButton(name: "Drug 1", count: 2, refill: 2, isOn: true)
    }
}
