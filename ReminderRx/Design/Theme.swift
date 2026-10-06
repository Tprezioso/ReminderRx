//
//  Theme.swift
//  ReminderRx
//

import SwiftUI

enum Theme {
    static let cornerRadius: CGFloat = 24
    static let spacing: CGFloat = 16

    /// The playful brand gradient used for hero elements like the daily ring.
    static let brandColors: [Color] = [.indigo, .purple, .pink]
    static let ringColors: [Color] = [.indigo, .purple, .pink, .orange]

    static func adherenceColor(_ rate: Double) -> Color {
        switch rate {
        case 0.8...: .green
        case 0.5..<0.8: .orange
        default: .red
        }
    }
}

/// A soft brand-tinted wash behind grouped content.
struct BrandBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.22), Color.purple.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 420)
        }
        .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.spacing

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

extension View {
    func card(padding: CGFloat = Theme.spacing) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// A rounded, tinted label such as "Due now" or "Taken 8:04 AM".
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: .capsule)
    }
}
