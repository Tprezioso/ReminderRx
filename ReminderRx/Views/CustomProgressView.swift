//
//  CustomProgressView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 3/17/22.
//

import SwiftUI

struct CustomProgressView: View {
    @Binding var progress: String
    @Binding var total: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5.0)
                .opacity(0.3)
                .foregroundColor(Color.gray)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(convertProgress(progress)))
                .stroke(AngularGradient(colors: [.red, .orange, .yellow, .green], center: .center), style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.red)
                .rotationEffect(.degrees(-90))
            
            Text(self.progress)
                .font(.largeTitle)
                .bold()
        }.frame(width: 75, height: 75)
        .padding()
    }
    
    func convertProgress(_ progress: String) -> Float {
        if let floatValue = Float(progress) {
            print("Float value = \(floatValue / Float(total)!)")
            return floatValue / Float(total)!
        }
        return 0.0
    }
}

struct CustomProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomProgressView(progress: .constant("90"), total: .constant("100"))
            CustomProgressView(progress: .constant("90"), total: .constant("100"))
                .preferredColorScheme(.dark)
        }
    }
}
