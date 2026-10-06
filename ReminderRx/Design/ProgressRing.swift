//
//  ProgressRing.swift
//  ReminderRx
//

import SwiftUI

/// An animated gradient ring with content in the middle.
struct ProgressRing<Label: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var colors: [Color] = Theme.ringColors
    @ViewBuilder var label: Label

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(colors: colors, center: .center, startAngle: .zero, endAngle: .degrees(360 * max(clamped, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(clamped == 0 ? 0 : 1)
            label
        }
        .animation(.spring(duration: 0.8, bounce: 0.3), value: clamped)
    }
}

#Preview {
    ProgressRing(progress: 0.6) {
        Text("3/5").font(.title.bold())
    }
    .frame(width: 140, height: 140)
}
