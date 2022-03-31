//
//  EditRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/30/21.
//

import SwiftUI

struct EditRxView: View {
    @Environment(\.managedObjectContext) var moc
    @StateObject var notificationManager = NotificationManager()
    @StateObject var stateModel: EditRxStateModel
    @Binding var isShowingDetail: Bool
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Section(header: Text("Name")) {
                            TextField("Rx Name", text: $stateModel.name)
                                .onChange(of: stateModel.name, perform: { value in
                                    if stateModel.name.count > 50 {
                                        stateModel.name = String(stateModel.name.prefix(50))
                                    }
                                })
                                .validation(stateModel.nameValidation)
                        }
                        Section(header: Text("Total Number of Pills")) {
                            TextField("Starting Number of Pills", text: $stateModel.countTotal)
                                .onChange(of: stateModel.countTotal, perform: { value in
                                    if stateModel.countTotal.count > 5 {
                                        stateModel.countTotal = String(stateModel.countTotal.prefix(5))
                                    }
                                })
                                .validation(stateModel.countTotalValidation)
                                .keyboardType(.numberPad)
                        }
                        Section(header: Text("Current Number of Pills")) {
                            TextField("Number of Pills", text: $stateModel.count)
                                .onChange(of: stateModel.count, perform: { value in
                                    if stateModel.count.count > 5 {
                                        stateModel.count = String(stateModel.count.prefix(5))
                                    }
                                })
                                .validation(stateModel.countValidation)
                                .keyboardType(.numberPad)
                        }
                        Section(header: Text("Refill amount")) {
                            TextField("Refills", text: $stateModel.refills)
                                .onChange(of: stateModel.refills, perform: { value in
                                    if stateModel.refills.count > 3 {
                                        stateModel.refills = String(stateModel.refills.prefix(3))
                                    }
                                })
                                .validation(stateModel.refillValidation)
                                .keyboardType(.numberPad)
                        }
                        Toggle("Marked as Pill Taken Today", isOn: $stateModel.prescription.isOn)
                        Section(header: Text("Set Notification Reminder")) {
                            if notificationManager.authorizationStatus == .denied {
                                Text("Please go into your setting and enable Notification to use daily notification reminders")
                            } else {
                                Toggle("Daily notification reminder", isOn: $stateModel.prescription.isNotificationOn)
                                if stateModel.prescription.isNotificationOn {
                                    DatePicker("Time", selection: $stateModel.date, displayedComponents: [.hourAndMinute])
                                }
                            }
                        }
                    }.listStyle(PlainListStyle())
                        .navigationTitle("Edit Prescription")
                    Spacer()
                    Button {
                        if stateModel.prescription.isNotificationOn {
                            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: stateModel.date)
                            guard let hour = dateComponents.hour, let minute = dateComponents.minute else { return }
                            Task { @MainActor in
                                await notificationManager.updateLocalNotification(id: stateModel.id.uuidString, title: stateModel.name, hour: hour, minute: minute)
                            }
                        } else {
                            notificationManager.removeNotificationWith(id:stateModel.prescription.id?.uuidString ?? UUID().uuidString)
                        }
                        stateModel.savePrescription(stateModel.prescription)
                        try? moc.save()
                        isShowingDetail = false
                    } label: {
                        SaveButtonView()
                    }.onReceive(stateModel.allValidation) { validation in
                        stateModel.isSaveDisabled = !validation.isSuccess
                    }.disabled(stateModel.name.isEmpty || stateModel.countTotal.isEmpty || stateModel.count.isEmpty || stateModel.refills.isEmpty)
                        .opacity(stateModel.name.isEmpty || stateModel.countTotal.isEmpty || stateModel.count.isEmpty || stateModel.refills.isEmpty ? 0.4 : 1)
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

struct EditRxView_Previews: PreviewProvider {
    static var previews: some View {
        EditRxView(stateModel: EditRxStateModel(prescription: Prescriptions()), isShowingDetail: .constant(true))
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
