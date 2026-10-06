//
//  RootView.swift
//  ReminderRx
//

import ReminderRxKit
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Query private var medications: [Medication]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(SettingsView.defaultLowSupplyThresholdKey) private var defaultLowSupplyThreshold = 7

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Today", systemImage: "checklist", value: AppRouter.Tab.today) {
                TodayView()
            }
            Tab("Medications", systemImage: "pills.fill", value: AppRouter.Tab.medications) {
                MedicationsView()
            }
            Tab("History", systemImage: "chart.bar.fill", value: AppRouter.Tab.history) {
                HistoryView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        #if DEBUG
        .task { router.applyDebugLaunchArguments(medications: medications.sorted { $0.name < $1.name }) }
        #endif
        .sheet(item: $router.editor) { route in
            MedicationEditorView(model: editorModel(for: route))
        }
        .sheet(isPresented: $router.isShowingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: Binding { !hasCompletedOnboarding } set: { hasCompletedOnboarding = !$0 }) {
            OnboardingView(importedCount: LegacyImporter.importedCount) { addMedication in
                hasCompletedOnboarding = true
                if addMedication {
                    Task {
                        // Let the cover finish dismissing before presenting the editor.
                        try? await Task.sleep(for: .milliseconds(500))
                        router.editor = .new
                    }
                }
            }
        }
    }

    private func editorModel(for route: AppRouter.EditorRoute) -> MedicationEditorModel {
        switch route {
        case .new:
            MedicationEditorModel(medication: nil, colorIndex: medications.count, defaultLowSupplyThreshold: defaultLowSupplyThreshold)
        case .edit(let medication):
            MedicationEditorModel(medication: medication)
        }
    }
}
