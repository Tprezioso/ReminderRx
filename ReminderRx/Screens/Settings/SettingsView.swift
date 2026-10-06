//
//  SettingsView.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    static let defaultLowSupplyThresholdKey = "defaultLowSupplyThreshold"

    @Environment(NotificationService.self) private var notificationService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReminderSettings.nudgesEnabledKey, store: SharedStore.defaults) private var nudgesEnabled = true
    @AppStorage(ReminderSettings.refillAlertsEnabledKey, store: SharedStore.defaults) private var refillAlertsEnabled = true
    @AppStorage(Self.defaultLowSupplyThresholdKey) private var defaultLowSupplyThreshold = 7

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection

                Section {
                    Toggle(isOn: $nudgesEnabled) {
                        Label("Missed-dose nudges", systemImage: "bell.badge.fill")
                    }
                    Toggle(isOn: $refillAlertsEnabled) {
                        Label("Refill alerts", systemImage: "arrow.clockwise.circle.fill")
                    }
                } footer: {
                    Text("Nudges arrive 30 minutes after a dose that hasn't been logged. Refill alerts come once when a medication runs low.")
                }

                Section {
                    Stepper("Warn at \(defaultLowSupplyThreshold) left", value: $defaultLowSupplyThreshold, in: 1...90)
                } header: {
                    Text("New Medications")
                } footer: {
                    Text("The starting low-supply warning for medications you add. You can change it for each one.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                    Text("ReminderRx is a reminder and tracking tool. It isn't medical advice — always follow your prescriber's instructions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                DebugSection()
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            .onChange(of: nudgesEnabled) { ReminderScheduler.setNeedsReschedule() }
            .onChange(of: refillAlertsEnabled) { ReminderScheduler.setNeedsReschedule() }
            .task { await notificationService.refresh() }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            switch notificationService.authorizationStatus {
            case .notDetermined:
                Button("Turn On Reminders", systemImage: "bell.fill") {
                    Task { await notificationService.requestAuthorizationIfNeeded() }
                }
            case .denied:
                Label("Notifications are off", systemImage: "bell.slash.fill")
                    .foregroundStyle(.red)
                Button("Open Settings", systemImage: "gear") { notificationService.openSystemSettings() }
            default:
                Label("Reminders are on", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

#if DEBUG
private struct DebugSection: View {
    @Query(sort: \Medication.name) private var medications: [Medication]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var pendingCount = 0

    var body: some View {
        Section("Debug") {
            if let medication = medications.first(where: { !$0.isArchived }) {
                Button("Send Test Reminder in 5s") {
                    Task { await ReminderScheduler.sendTestReminder(for: medication) }
                }
            }
            LabeledContent("Pending notifications", value: "\(pendingCount)")
            Button("Show Onboarding Again") { hasCompletedOnboarding = false }
        }
        .task { pendingCount = await ReminderScheduler.pendingCount() }
    }
}
#endif

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
