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
                    .navigationTitle("Reminder RX")
                }.listStyle(PlainListStyle())
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
                stateModel.checkIfItsANewDay()
            } else if newPhase == .background {
                print("Background")
            }
        }
        .onAppear {
            print(prescriptions)
        }
    }
    
    func updatePrescription(_ prescription: Prescriptions) {
        let newCount: Int64 = prescription.count - 1
        let wasTapped = true
        
        moc.performAndWait {
            prescription.count = newCount
            prescription.isOn = wasTapped
            try? moc.save()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

class Prescription: Identifiable {
    var id = UUID()
    var name = ""
    @State var count = 0
    var refills = 0
    @State var isOn = false
    
    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}
