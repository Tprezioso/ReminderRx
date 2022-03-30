//
//  AddRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/20/21.
//

import SwiftUI

struct AddRxView: View {
    @Environment(\.managedObjectContext) var moc
    @StateObject var stateModel = AddRxStateModel()
    @StateObject var notificationManager = NotificationManager()
    @Binding var isShowingDetail: Bool
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Section(header: Text("New Rx")) {
                            TextField("Rx Name", text: $stateModel.name)
                                .onChange(of: stateModel.name, perform: { value in
                                       if stateModel.name.count > 50 {
                                           stateModel.name = String(stateModel.name.prefix(50))
                                      }
                                  })
                                .validation(stateModel.nameValidation)
                            TextField("Number of Pills", text: $stateModel.count)
                                .onChange(of: stateModel.count, perform: { value in
                                       if stateModel.count.count > 5 {
                                           stateModel.count = String(stateModel.count.prefix(5))
                                      }
                                  })
                                .validation(stateModel.countValidation)
                                .keyboardType(.numberPad)
                            TextField("Refills", text: $stateModel.refills)
                                .onChange(of: stateModel.refills, perform: { value in
                                       if stateModel.refills.count > 3 {
                                           stateModel.refills = String(stateModel.count.prefix(3))
                                      }
                                  })
                                .validation(stateModel.refillValidation)
                                .keyboardType(.numberPad)
                        }.navigationTitle("Add Prescription")
                        Section(header: Text("Set Notification Reminder")) {
                            if notificationManager.authorizationStatus == .denied {
                                Text("Please go into your setting and enable Notification to use daily notification reminders")
                            } else {
                                Toggle("Daily notification reminder", isOn: $stateModel.isNotificationOn)
                                    .onChange(of: stateModel.isNotificationOn) { value in
                                        if !value { notificationManager.removeNotificationWith(id: stateModel.id.uuidString) }
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
        
    }
}

struct AddRxView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddRxView(isShowingDetail: .constant(true))
        }
    }
}
