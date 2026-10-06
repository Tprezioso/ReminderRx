//
//  AppShortcuts.swift
//  ReminderRx
//

import AppIntents
import ReminderRxKit

struct ReminderRxAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [ReminderRxKitIntents.self] }
}

/// Siri phrases and Shortcuts app actions, available without any setup.
struct ReminderRxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeNextDoseIntent(),
            phrases: [
                "Log my dose in \(.applicationName)",
                "I took my medication in \(.applicationName)",
                "Take my next dose in \(.applicationName)",
            ],
            shortTitle: "Take Next Dose",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: MarkDoseTakenIntent(),
            phrases: [
                "I took \(\.$medication) in \(.applicationName)",
                "Log \(\.$medication) in \(.applicationName)",
            ],
            shortTitle: "Take Medication",
            systemImageName: "pills.fill"
        )
        AppShortcut(
            intent: NextDoseIntent(),
            phrases: [
                "What's my next med in \(.applicationName)",
                "When is my next dose in \(.applicationName)",
            ],
            shortTitle: "Next Medication",
            systemImageName: "bell.fill"
        )
        AppShortcut(
            intent: LogAsNeededDoseIntent(),
            phrases: [
                "Log an as-needed dose in \(.applicationName)",
            ],
            shortTitle: "Log As-Needed Dose",
            systemImageName: "hand.tap.fill"
        )
    }
}
