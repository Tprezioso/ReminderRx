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
                List {
                    if !prescriptions.isEmpty {
                        ForEach(prescriptions) { prescription in
                            Button {
                                updatePrescription(prescription)
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

                    } else {
                        Text("Add a prescription")
                    }
                    
                }.navigationTitle("Reminder RX")
                .listStyle(PlainListStyle())
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
                print("Inactive")
            } else if newPhase == .active {
                updatePrescriptionOnLoad(prescriptions)
            } else if newPhase == .background {
                print("Background")
            }
        }
        .onAppear {
            print(prescriptions)
        }
    }
    
    func updatePrescription(_ prescription: Prescriptions) {
        var newCount = Int64()
        var wasTapped = false
        
        if !stateModel.theDayHasChanged() && !prescription.isOn {
            newCount = prescription.count - 1
            wasTapped = true
            moc.performAndWait {
                prescription.count = newCount
                prescription.isOn = wasTapped
                try? moc.save()
            }
        }
    }
    
    func updatePrescriptionOnLoad(_ prescriptions: FetchedResults<Prescriptions>) {
        if stateModel.theDayHasChanged() {
            for prescription in prescriptions {
                moc.performAndWait {
                    prescription.isOn = false
                    try? moc.save()
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
