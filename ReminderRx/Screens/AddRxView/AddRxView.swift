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
                            TextField("Number of Pills", text: $stateModel.count)
                                .keyboardType(.numberPad)
                            TextField("Refills", text: $stateModel.refills)
                                .keyboardType(.numberPad)
                        }.navigationTitle("Add Prescription")
                        Section(header: Text("Set Notification Reminder")) {
                            if notificationManager.authorizationStatus == .denied {
                                Text("Please go into your setting and enable Notification to use daily notification reminders")
                            } else {
                                Toggle("Daily notification reminder", isOn: $stateModel.isNotificationOn)
                                    .onChange(of: stateModel.isNotificationOn) { value in
//                                        if value { notificationManager.reloadAuthorizationStatus() }
                                        if !value { notificationManager.removeAllNotifications(id: stateModel.id.uuidString) }
                                    }
                                if stateModel.isNotificationOn {
                                    HStack {
                                        Text("Time")
                                        Spacer()
                                        DatePicker("", selection: $stateModel.date, displayedComponents: [.hourAndMinute])
                                    }
                                }
                            }
                        }
                    }.listStyle(PlainListStyle())
                    Spacer()
                    Button {
                        let savedPrescription = Prescriptions(context: moc)
                        stateModel.savePrescription(savedPrescription)
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
        
    }
}

struct AddRxView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddRxView(isShowingDetail: .constant(true))
        }
    }
}

class AddRxStateModel: ObservableObject {
    @Published var id = UUID()
    @Published var name = ""
    @Published var count = ""
    @Published var refills = ""
    @Published var date = Date()
    @Published var isNotificationOn = false
    
    func savePrescription(_ prescription: Prescriptions) {
        prescription.id = id
        prescription.name = name
        prescription.count = count
        prescription.refills = refills
        prescription.isOn = false
        prescription.isNotificationOn = isNotificationOn
    }
}
