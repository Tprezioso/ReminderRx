//
//  ReminderRxWidgetsBundle.swift
//  ReminderRxWidgets
//
//  Created by Thomas Prezioso Jr on 10/5/26.
//

import AppIntents
import ReminderRxKit
import SwiftUI
import WidgetKit

struct ReminderRxWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [ReminderRxKitIntents.self] }
}

@main
struct ReminderRxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextDoseWidget()
        TakeNextDoseControl()
    }
}

/// "Take Next Dose" for Control Center, the Lock Screen and the Action button.
struct TakeNextDoseControl: ControlWidget {
    static let kind = "com.Swifttom.ReminderRx.TakeNextDoseControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TakeNextDoseIntent()) {
                Label("Take Next Dose", systemImage: "pills.fill")
            }
        }
        .displayName("Take Next Dose")
        .description("Logs the dose that's due now, or one coming up within the hour.")
    }
}
