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
                PrescriptionCellButton(prescription: example)
            }.listStyle(PlainListStyle())
                .navigationTitle("Reminder RX")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

class Prescription: Identifiable {
    let id = UUID()
    var name = ""
    var count = 0
    @State var isOn = false
    
    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}
