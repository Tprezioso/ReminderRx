//
//  PrescriptionProgressView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 3/17/22.
//

import SwiftUI

struct PrescriptionProgressView: View {
    @StateObject var prescription: Prescriptions
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5.0)
                .opacity(0.3)
                .foregroundColor(Color.gray)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(convertPrescriptionCount(prescription.count ?? "")))
                .stroke(AngularGradient(colors: [.red, .orange, .yellow, .green], center: .center), style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.red)
                .rotationEffect(.degrees(-90))
            
            Text(prescription.count ?? "")
                .bold()
                .minimumScaleFactor(0.5)
                .font(.largeTitle)
                .padding(.horizontal, 5)
        }.frame(width: 75, height: 75)
        .padding()
    }
    
    func convertPrescriptionCount(_ count: String) -> Float {
        if let floatValue = Float(prescription.count ?? "") {
            return floatValue / (Float(prescription.countTotal ?? "") ?? 0.0) 
        }
        return 0.0
    }
}

struct CustomProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PrescriptionProgressView(prescription: Prescriptions())
            PrescriptionProgressView(prescription: Prescriptions())
                .preferredColorScheme(.dark)
        }
    }
}
