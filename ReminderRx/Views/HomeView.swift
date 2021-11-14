//
//  HomeView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/9/21.
//

import SwiftUI

struct HomeView: View {
    var exampleArray = [
        Prescription(name: "Drug 1", count: 99),
        Prescription(name: "Drug 2", count: 10),
        Prescription(name: "Drug 3", count: 12),
        Prescription(name: "Drug 4", count: 56),
        Prescription(name: "Drug 5", count: 34),
        Prescription(name: "Drug 6", count: 2)
    ]
    @State var isTapped = false
    
    var body: some View {
        NavigationView {
            List(exampleArray) { example in
                Button {
                    isTapped.toggle()
                } label: {
                    PrescriptionCell(prescription: example, isOn: isTapped)
                }
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

struct Prescription: Identifiable {
    let id = UUID()
    var name = ""
    var count = 0
    
}
