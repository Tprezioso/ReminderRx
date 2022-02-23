//
//  EditRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/30/21.
//

import SwiftUI
import EventKit

struct EditRxView: View {
    @State var date = Date()
    @Binding var isShowingDetail: Bool
    @AppStorage("hasDailyReminder") var hasDailyReminder = false
    @ObservedObject var prescription: Prescriptions
    @Environment(\.managedObjectContext) var moc
    @StateObject var notificationManager = NotificationManager()
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Section(header: Text("Edit")) {
                            TextField("Rx Name", text: Binding($prescription.name, ""))
                            TextField("Number of Pills", text: Binding($prescription.count, ""))
                                .keyboardType(.numberPad)
                            TextField("Refills", text: Binding($prescription.refills, ""))
                                .keyboardType(.numberPad)
                            Toggle("Marked as Checked", isOn: $prescription.isOn)
                        }
                        Section(header: Text("Set Notification Reminder")) {
                            Toggle("Daily notification reminder", isOn: $hasDailyReminder)
                                .onChange(of: hasDailyReminder) { value in
                                    if !value { notificationManager.removeAllNotifications() }
                                }
                            if hasDailyReminder {
                                HStack {
                                    Text("Time")
                                    Spacer()
                                    DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                                }
                            }
                        }
                        .navigationTitle("Edit Prescription")
                    }.listStyle(PlainListStyle())
                    Spacer()
                    Button {
                        Task { @MainActor in
                            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
                            guard let hour = dateComponents.hour, let minute = dateComponents.minute else { return }
                            await notificationManager.createLocalNotification(title: prescription.name ?? "", hour: hour, minute: minute)
                        }
                        try? moc.save()
                        isShowingDetail = false
                    } label: {
                        SaveButtonView()
                    }
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isShowingDetail = false
                    } label: {
                        XDismissButton()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            notificationManager.reloadAuthorizationStatus()
        }
        .onDisappear {
            notificationManager.reloadLocalNotifications()
        }
        .onChange(of: notificationManager.authorizationStatus) { authorizationStatus in
            switch authorizationStatus {
            case .notDetermined:
                notificationManager.requestAuthorization()
            case .authorized:
                notificationManager.reloadLocalNotifications()
            default:
                break
            }
        }
    }
}

struct EditRxView_Previews: PreviewProvider {
    static var previews: some View {
        EditRxView(isShowingDetail: .constant(true), prescription: Prescriptions())
    }
}

extension Binding {
    init(_ source: Binding<Value?>, _ defaultValue: Value) {
        // Ensure a non-nil value in `source`.
        if source.wrappedValue == nil {
            source.wrappedValue = defaultValue
        }
        // Unsafe unwrap because *we* know it's non-nil now.
        self.init(source)!
    }
}
