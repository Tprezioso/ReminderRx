//
//  AppRouter.swift
//  ReminderRx
//

import Foundation
import Observation
import ReminderRxKit

/// App-wide navigation state, shared with the notification delegate so a tapped reminder can open Today.
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case today, medications, history
    }

    enum EditorRoute: Identifiable {
        case new
        case edit(Medication)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let medication): medication.id.uuidString
            }
        }
    }

    static let shared = AppRouter()

    var selectedTab: Tab = .today
    var editor: EditorRoute?
    var isShowingSettings = false

    #if DEBUG
    /// Opens a tab or sheet from launch arguments (`-debugTab history`, `-debugSheet editor`)
    /// so screens can be captured from the command line.
    func applyDebugLaunchArguments(medications: [Medication]) {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "debugTab") {
        case "medications": selectedTab = .medications
        case "history": selectedTab = .history
        default: break
        }
        switch defaults.string(forKey: "debugSheet") {
        case "new": editor = .new
        case "editor": editor = medications.first.map(EditorRoute.edit)
        case "settings": isShowingSettings = true
        default: break
        }
    }
    #endif
}
