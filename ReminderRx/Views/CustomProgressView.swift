//
//  CustomProgressView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 3/17/22.
//

import SwiftUI

struct CustomProgressView: View {
    @Binding var progress: String
//    @State var total: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10.0)
                .opacity(0.3)
                .foregroundColor(Color.red)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(convertProgress(progress)))
                .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
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
            print("Float value = \(floatValue / 100)")
            return floatValue / 100
        }
        return 0.0
    }
}

struct CustomProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomProgressView(progress: .constant("95"))
//            CustomProgressView(progress: .constant(0.9), total: 100)
//                .preferredColorScheme(.dark)
        }
    }
}
