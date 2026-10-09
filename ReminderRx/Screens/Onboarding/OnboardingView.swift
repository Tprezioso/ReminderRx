//
//  OnboardingView.swift
//  ReminderRx
//

import SwiftUI

/// First-launch welcome, or a "What's new" tour for people upgrading from 1.x.
struct OnboardingView: View {
    enum Page: Hashable {
        case welcome, whatsNew, features, notifications, firstMedication
    }

    enum NextStep {
        case done, addMedication, importFromHealth
    }

    /// Prescriptions brought over from 1.x; zero for a new install.
    let importedCount: Int
    let onFinish: (NextStep) -> Void

    @Environment(NotificationService.self) private var notificationService
    @State private var page: Page

    private var pages: [Page] {
        importedCount > 0 ? [.whatsNew, .notifications] : [.welcome, .features, .notifications, .firstMedication]
    }

    init(importedCount: Int, onFinish: @escaping (NextStep) -> Void) {
        self.importedCount = importedCount
        self.onFinish = onFinish
        _page = State(initialValue: importedCount > 0 ? .whatsNew : .welcome)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages, id: \.self) { page in
                    pageContent(page)
                        .padding(.horizontal, 28)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            buttons
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(BrandBackground())
        .sensoryFeedback(.selection, trigger: page)
    }

    @ViewBuilder
    private func pageContent(_ page: Page) -> some View {
        switch page {
        case .welcome:
            OnboardingPage(
                hero: AnimatedHero(),
                title: "Never miss a dose",
                message: "Script Tracker keeps track of what to take and when, and nudges you if you forget."
            )
        case .whatsNew:
            ScrollView {
                VStack(spacing: 24) {
                    AnimatedHero().frame(height: 160)
                    VStack(spacing: 8) {
                        Text("Welcome to Script Tracker 2.0")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("We brought over your \(importedCount) prescription\(importedCount == 1 ? "" : "s"). Here's what's new:")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    FeatureList()
                }
                .padding(.vertical, 32)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 56, for: .scrollContent)
        case .features:
            ScrollView {
                VStack(spacing: 24) {
                    Text("Everything in one place")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    FeatureList()
                }
                .padding(.vertical, 40)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 56, for: .scrollContent)
        case .notifications:
            OnboardingPage(
                hero: HeroSymbol(name: "bell.badge.fill", colors: [.orange, .pink]),
                title: "Reminders that do more",
                message: "Mark a dose taken, snooze it or skip it right from the notification — no need to open the app."
            )
        case .firstMedication:
            OnboardingPage(
                hero: HeroSymbol(name: "plus.circle.fill", colors: [.green, .teal]),
                title: "Add your first medication",
                message: "Set how often you take it, when to remind you, and how much you have left."
            )
        }
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 12) {
            switch page {
            case .notifications where !notificationService.isAuthorized:
                primaryButton("Turn On Reminders") {
                    Task {
                        await notificationService.requestAuthorizationIfNeeded()
                        advance()
                    }
                }
                secondaryButton("Not Now") { advance() }
            case .firstMedication:
                primaryButton("Add Medication") { onFinish(.addMedication) }
                secondaryButton("Import from Apple Health") { onFinish(.importFromHealth) }
                secondaryButton("Maybe Later") { onFinish(.done) }
            default:
                primaryButton(page == pages.last ? "Get Started" : "Continue") { advance() }
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
    }

    private func advance() {
        guard let index = pages.firstIndex(of: page), index + 1 < pages.count else {
            onFinish(.done)
            return
        }
        withAnimation { page = pages[index + 1] }
    }
}

private struct OnboardingPage<Hero: View>: View {
    let hero: Hero
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            hero.frame(height: 200)
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
    }
}

private struct HeroSymbol: View {
    let name: String
    let colors: [Color]
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 110, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .symbolEffect(.bounce, value: isAnimating)
            .onAppear { isAnimating.toggle() }
            .accessibilityHidden(true)
    }
}

/// The daily ring filling up around a pill.
private struct AnimatedHero: View {
    @State private var progress = 0.0

    var body: some View {
        ProgressRing(progress: progress, lineWidth: 18) {
            Image(systemName: "pills.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: Theme.brandColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.bounce, value: progress)
        }
        .frame(width: 170, height: 170)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            progress = 0.8
        }
        .accessibilityHidden(true)
    }
}

private struct FeatureList: View {
    private let features: [(symbol: String, color: Color, title: String, detail: String)] = [
        ("checklist", .indigo, "Today at a glance", "Every dose by time of day, with a progress ring and streaks."),
        ("calendar.badge.clock", .purple, "Flexible schedules", "Several times a day, specific weekdays, every few days or as needed."),
        ("bell.badge.fill", .orange, "Actionable reminders", "Taken, Snooze and Skip right on the notification."),
        ("chart.bar.fill", .green, "History & stats", "See how you're doing over the last week or month."),
        ("arrow.clockwise.circle.fill", .teal, "Refill alerts", "Know when you're running low before you run out."),
        ("widget.small", .pink, "Widgets & Siri", "Log a dose from your Home Screen, Lock Screen or Siri."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(features, id: \.title) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.symbol)
                        .font(.title2)
                        .foregroundStyle(feature.color)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.headline)
                        Text(feature.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
