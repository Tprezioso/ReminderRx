//
//  EditRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/30/21.
//

import SwiftUI
import Combine

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
                        Section(header: Text("Edit")) {
                            TextField("Rx Name", text: $stateModel.name)
                                .validation(stateModel.nameValidation)
                            TextField("Number of Pills", text: $stateModel.count)
                                .validation(stateModel.countValidation)
                                .keyboardType(.numberPad)
                            TextField("Refills", text: $stateModel.refills)
                                .validation(stateModel.refillValidation)
                                .keyboardType(.numberPad)
                            Toggle("Marked as Checked", isOn: $stateModel.prescription.isOn)
                        }
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
                        .navigationTitle("Edit Prescription")
                    }.listStyle(PlainListStyle())
                    Spacer()
                    Button {
                        if stateModel.prescription.isNotificationOn {
                            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: stateModel.date)
                            guard let hour = dateComponents.hour, let minute = dateComponents.minute else { return }
                            Task { @MainActor in
                              await notificationManager.updateLocalNotification(id: stateModel.id.uuidString, title: stateModel.name, hour: hour, minute: minute)
                            }
                        } else {
                            notificationManager.removeAllNotifications(id:stateModel.prescription.id?.uuidString ?? UUID().uuidString)
                        }
                        stateModel.savePrescription(stateModel.prescription)
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

class EditRxStateModel: ObservableObject {
    @Published var date = Date()
    @Published var id: UUID
    @Published var name = ""
    @Published var count = ""
    @Published var refills = ""
    @Published var prescription: Prescriptions
    @Published var isNotificationOn: Bool
    @Published var isSaveDisabled = true
    
    init(prescription: Prescriptions) {
        self.prescription = prescription
        self.id = prescription.id ?? UUID()
        self.name = prescription.name ?? ""
        self.count = prescription.count ?? ""
        self.refills = prescription.refills ?? ""
        self.date = prescription.savedDate ?? Date()
        self.isNotificationOn = prescription.isNotificationOn
    }
    
    func savePrescription(_ prescription: Prescriptions) {
        prescription.name = name
        prescription.count = count
        prescription.refills = refills
        prescription.savedDate = date
    }
    
    lazy var nameValidation: ValidationPublisher = {
        $name.nonEmptyValidator("Please enter a prescription name")
    }()
    
    lazy var countValidation: ValidationPublisher = {
        $count.nonEmptyValidator("Please enter the number of pills in your prescription")
    }()
    
    lazy var refillValidation: ValidationPublisher = {
        $refills.nonEmptyValidator("Please enter any refills")
    }()
    
    
    lazy var allValidation: ValidationPublisher = {
            Publishers.CombineLatest3(
                nameValidation,
                countValidation,
                refillValidation
            ).map { v1, v2, v3 in
                return [v1, v2, v3].allSatisfy { $0.isSuccess } ? .success : .failure(message: "")
            }.eraseToAnyPublisher()
    }()
}
