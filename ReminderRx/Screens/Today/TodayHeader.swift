//
//  TodayHeader.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftUI

/// The daily progress ring, streak and a one-line "what's next".
struct TodayHeader: View {
    let taken: Int
    let total: Int
    let streak: Int
    let nextEntry: DoseEntry?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var progress: Double { total == 0 ? 0 : Double(taken) / Double(total) }

    var body: some View {
        // Side by side normally; stacked at accessibility text sizes so nothing gets squeezed.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 20))

        layout {
            ProgressRing(progress: progress, lineWidth: 16) {
                VStack(spacing: 0) {
                    Text("\(taken)/\(total)")
                        .font(.title.bold())
                        .contentTransition(.numericText(value: Double(taken)))
                    Text("doses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 20)
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 10) {
                Text(headline)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                if let nextEntry {
                    Label {
                        Text("\(nextEntry.medication.name) at \(nextEntry.dose.scheduledDate.formatted(date: .omitted, time: .shortened))")
                    } icon: {
                        Image(systemName: "bell.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if streak > 0 {
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15), in: .capsule)
                        .symbolEffect(.bounce, value: streak)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 20)
        .animation(.snappy, value: taken)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        if total == 0 { return "Nothing scheduled today" }
        if taken == total { return "You're all set for today!" }
        if taken == 0 { return "Let's get started" }
        return "\(total - taken) to go — nice work"
    }
}
