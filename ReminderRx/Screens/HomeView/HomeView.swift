//
//  HomeView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/9/21.
//

import SwiftUI
import CoreData

struct HomeView: View {    
    @StateObject var stateModel = HomeViewStateModel()
    @FetchRequest(sortDescriptors: []) var prescriptions: FetchedResults<Prescriptions>
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        NavigationView {
            ZStack {
                if !prescriptions.isEmpty {
                    List {
                        ForEach(prescriptions) { prescription in
                            Button {
                                stateModel.updatePrescription(prescription)
                            } label: {
                                PrescriptionCellButton(prescription: prescription)
                            }
                            .swipeActions {
                                Button {
                                    print("Delete")
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
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")
                                }
                                .tint(.yellow)
                            }
                            .sheet(isPresented: $stateModel.editButtonTapped) {
                                EditRxView(isShowingDetail: $stateModel.editButtonTapped)
                            }
                        }
                    }
                    .navigationTitle("Reminder RX")
                    .listStyle(.plain)
                } else {
                    EmptyStateView(message: "Add a Prescription")
                        .navigationTitle("Reminder RX")
                }
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
