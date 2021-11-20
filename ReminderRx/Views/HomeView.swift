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
            List(stateModel.exampleArray) { example in
                PrescriptionCellButton(prescription: example, isOn: stateModel.isItaNewDay)
            }.listStyle(PlainListStyle())
            .navigationTitle("Reminder RX")
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
