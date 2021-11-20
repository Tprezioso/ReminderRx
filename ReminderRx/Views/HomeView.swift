//
//  HomeView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/9/21.
//

import SwiftUI

struct HomeView: View {    
    @StateObject var stateModel = HomeViewStateModel()
    
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
                        //                        .sheet(isPresented: $stateModel.plusButtonTapped){
                        //
                        //                        }
                    }
                }
                BottomSheetView(
                    isOpen: $stateModel.plusButtonTapped,
                    maxHeight: CGFloat(400)
                    
                ) {
                    EmptyView()
                }

            }
        }.onAppear {
            stateModel.checkIfItsANewDay()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

class Prescriptions: Identifiable {
    let id = UUID()
    var name = ""
    var count = 0
    @State var isOn = false
    
    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}
