//
//  AddRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/20/21.
//

import SwiftUI

struct AddRxView: View {
    @StateObject var stateModel = AddRxStateModel()
    @Binding var isShowingDetail: Bool
    @Environment(\.managedObjectContext) var moc
    @StateObject var notificationManager = NotificationManager()

    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Section(header: Text("New Rx")) {
                            TextField("Rx Name", text: $stateModel.name)
                                .validation(stateModel.nameValidation)
                            TextField("Number of Pills", text: $stateModel.count)
                                .validation(stateModel.countValidation)
                                .keyboardType(.numberPad)
                            TextField("Refills", text: $stateModel.refills)
                                .validation(stateModel.refillValidation)
                                .keyboardType(.numberPad)
                        }.navigationTitle("Add Prescription")
                        Section(header: Text("Set Notification Reminder")) {
                            if notificationManager.authorizationStatus == .denied {
                                Text("Please go into your setting and enable Notification to use daily notification reminders")
                            } else {
                                Toggle("Daily notification reminder", isOn: $stateModel.isNotificationOn)
                                    .onChange(of: stateModel.isNotificationOn) { value in
                                        if !value { notificationManager.removeAllNotifications(id: stateModel.id.uuidString) }
                                    }
                                if stateModel.isNotificationOn {
                                    DatePicker("Time", selection: $stateModel.date, displayedComponents: [.hourAndMinute])
                                }
                            }
                        }
                    }.listStyle(PlainListStyle())
                    Spacer()
                    Button {
                        Task { @MainActor in
                            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: stateModel.date)
                            guard let hour = dateComponents.hour, let minute = dateComponents.minute else { return }
                            await notificationManager.createLocalNotification(id: stateModel.id.uuidString, title: stateModel.name, hour: hour, minute: minute)
                            let savedPrescription = Prescriptions(context: moc)
                            stateModel.savePrescription(savedPrescription)
                            try? moc.save()
                            isShowingDetail = false
                        }
                    } label: {
                        SaveButtonView()
                    }.onReceive(stateModel.allValidation) { validation in
                        stateModel.isSaveDisabled = !validation.isSuccess
                    }
                    .disabled(stateModel.isSaveDisabled)
                    .opacity(stateModel.isSaveDisabled ? 0.4 : 1)
                }.ignoresSafeArea(.keyboard)
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
        
    }
}

struct AddRxView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddRxView(isShowingDetail: .constant(true))
        }
    }
}
