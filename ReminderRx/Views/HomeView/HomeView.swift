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
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                moc.delete(prescriptions[index])
                            }
                            do {
                                try moc.save()
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                        
                    }.navigationTitle("Reminder RX")
                        .listStyle(PlainListStyle())
                } else {
                    Text("Add a Prescription")
                        .navigationTitle("Reminder RX")
                }
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Button {
                            stateModel.plusButtonTapped.toggle()
                        } label: {
                            ZStack {
                                Circle()
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 75, height: 75)
                                    .foregroundColor(.blue)
                                    .padding()
                            }
                            
                        }
                        .sheet(isPresented: $stateModel.plusButtonTapped){
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
        .onAppear {
            print(prescriptions)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
