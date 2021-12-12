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
    
    var body: some View {
        NavigationView {
            ZStack {
                List(stateModel.exampleArray) { example in
                    PrescriptionCellButton(prescription: example, isOn: stateModel.isANewDay)
                }.listStyle(PlainListStyle())
                    .navigationTitle("Reminder RX")
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
//                BottomSheetView(
//                    isOpen: $stateModel.plusButtonTapped,
//                    maxHeight: CGFloat(400)
//
//                ) {
//                    EmptyView()
//                }

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
    var count = 0
    var refills = 0
    @State var isOn = false
    
    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}
