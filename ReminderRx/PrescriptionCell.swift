//
//  PrescriptionCell.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/12/21.
//

import SwiftUI

struct PrescriptionCell: View {
    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text("Count:")
                    Text("99")
                }
                .frame(height: 100)
                .font(.largeTitle)
                .padding(.horizontal)
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "pills.circle")
                        Text("Name:")
                    }
                   
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Refill:")
                    }
                }
                Spacer()
            }
        }
    }
}

struct PrescriptionCell_Previews: PreviewProvider {
    static var previews: some View {
        PrescriptionCell()
    }
}
