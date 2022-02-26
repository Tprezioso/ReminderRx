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
    @AppStorage("hasDailyReminder") var hasDailyReminder = false

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
                            Toggle("Daily notification reminder", isOn: $hasDailyReminder)
                                .onChange(of: hasDailyReminder) { value in
                                    if !value { notificationManager.removeAllNotifications(id: stateModel.id.uuidString) }
                                }
                            if hasDailyReminder {
                                HStack {
                                    Text("Time")
                                    Spacer()
                                    DatePicker("", selection: $stateModel.date, displayedComponents: [.hourAndMinute])
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
    
    func savePrescription(_ prescription: Prescriptions) {
        prescription.id = id
        prescription.name = name
        prescription.count = count
        prescription.refills = refills
        prescription.isOn = false
    }
}
