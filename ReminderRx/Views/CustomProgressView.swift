//
//  CustomProgressView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 3/17/22.
//

import SwiftUI

struct CustomProgressView: View {
    @Binding var progress: CGFloat
    
    var body: some View {
        ZStack {
            // placeholder
            Circle()
                .stroke(lineWidth: 10)
                .foregroundColor(.gray)
                .opacity(0.2)
            
            // progress circle
            Circle()
                .trim(from: 0.0, to: min(progress, 1.0))
                .stroke(AngularGradient(colors: [.red, .orange, .yellow, .green], center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .butt, lineJoin: .miter))
                .rotationEffect(.degrees(-90))
                .shadow(radius: 2)
            
            Text("\(String(format: "%0.0f", progress * 100))")
                .bold()
            
        }
        .frame(width: 50, height: 50)
        .padding()
        .animation(.easeInOut, value: progress)
    }
}

struct CustomProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomProgressView(progress: .constant(0.9))
            CustomProgressView(progress: .constant(0.9))
                .preferredColorScheme(.dark)
        }
    }
}
