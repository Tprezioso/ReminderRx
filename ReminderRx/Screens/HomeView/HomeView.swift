//
//  HomeView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/9/21.
//

import SwiftUI
import CoreData

struct HomeView: View {    
    @FetchRequest(sortDescriptors: []) var prescriptions: FetchedResults<Prescriptions>
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.managedObjectContext) var moc
    @StateObject var stateModel = HomeViewStateModel()
    @StateObject var notificationManager = NotificationManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                if prescriptions.isEmpty {
                    EmptyStateView(message: "Add a Prescription")
                }
                List(prescriptions) { prescription in
                    Button {
                        stateModel.updatePrescription(prescription)
                    } label: {
                        PrescriptionCellButton(prescription: prescription)
                    }
                    .alert(isPresented: $stateModel.showingAlert) {
                        Alert(title: Text("Your Prescription is Done!"),
                              message: Text("Please get your prescription refilled and update your prescription information"),
                              dismissButton: .default(Text("OK"))
                        )
                    }
                    .alert(isPresented: $stateModel.forgotAlert) {
                        Alert(title: Text("Oops!"),
                              message: Text("It looks like you forgot to take \(stateModel.forgotRX.joined(separator: ", ")) yesterday. Don't forget to take them today!"),
                              dismissButton: .default(Text("OK"))
                        )
                    }
                    .swipeActions {
                        Button {
                            notificationManager.removeNotificationWith(id: prescription.id?.uuidString ?? "")
                            moc.delete(prescription)
                            do {
                                try moc.save()
                            } catch {
                                print(error.localizedDescription)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        
                        Button {
                            stateModel.editButtonTapped.toggle()
                            stateModel.prescription = prescription
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        .tint(.yellow)
                    }
                    .sheet(isPresented: $stateModel.editButtonTapped) {
                        let editRxStateModel = EditRxStateModel(prescription: stateModel.prescription)
                        EditRxView(stateModel: editRxStateModel, isShowingDetail: $stateModel.editButtonTapped)
                    }
                }
                .navigationTitle("Script Tracker")
                .listStyle(.plain)
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Button {
                            stateModel.plusButtonTapped.toggle()
                        } label: {
                            AddButtonView()
                        }
                        .sheet(isPresented: $stateModel.plusButtonTapped) {
                            AddRxView(isShowingDetail: $stateModel.plusButtonTapped)
                        }
                    }
                }
            }.onAppear {
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
        }.onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive {
                do {
                    try moc.save()
                } catch {
                    print("Failed saving")
                }
                print("Inactive")
            } else if newPhase == .active {
                stateModel.updatePrescriptionOnLoad(prescriptions)
            } else if newPhase == .background {
                print("Background")
                do {
                    try moc.save()
                } catch {
                    print("Failed saving")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
