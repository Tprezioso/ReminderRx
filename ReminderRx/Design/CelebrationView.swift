//
//  CelebrationView.swift
//  ReminderRx
//

import SwiftUI

/// A short burst of confetti-like symbols, shown when every dose for the day is taken.
struct CelebrationView: View {
    private struct Particle: Identifiable {
        let id = UUID()
        let symbol: String
        let color: Color
        let angle: Angle
        let distance: CGFloat
        let spin: Double
        let size: CGFloat
    }

    @State private var isExploded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particles: [Particle] = (0..<28).map { _ in
        Particle(
            symbol: ["star.fill", "heart.fill", "sparkle", "circle.fill", "pills.fill"].randomElement()!,
            color: [Color.indigo, .purple, .pink, .orange, .yellow, .green, .teal].randomElement()!,
            angle: .degrees(.random(in: 0..<360)),
            distance: .random(in: 120...260),
            spin: .random(in: -360...360),
            size: .random(in: 12...24)
        )
    }

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(particles) { particle in
                    Image(systemName: particle.symbol)
                        .font(.system(size: particle.size))
                        .foregroundStyle(particle.color)
                        .rotationEffect(.degrees(isExploded ? particle.spin : 0))
                        .offset(
                            x: isExploded ? cos(particle.angle.radians) * particle.distance : 0,
                            y: isExploded ? sin(particle.angle.radians) * particle.distance : 0
                        )
                        .opacity(isExploded ? 0 : 1)
                }
            }

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(LinearGradient(colors: Theme.brandColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, value: isExploded)
                Text("All done for today!")
                    .font(.title2.bold())
            }
            .padding(28)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .scaleEffect(isExploded ? 1 : 0.6)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 1.2, bounce: 0.4)) {
                isExploded = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All doses taken for today")
    }
}

#Preview {
    CelebrationView()
}
