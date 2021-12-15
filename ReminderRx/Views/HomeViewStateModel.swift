//
//  HomeViewStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/15/21.
//

import SwiftUI

class HomeViewStateModel: ObservableObject {
    @Published var exampleArray = [
        Prescription(name: "Drug 1", count: 99),
        Prescription(name: "Drug 2", count: 10),
        Prescription(name: "Drug 3", count: 12),
        Prescription(name: "Drug 4", count: 56),
        Prescription(name: "Drug 5", count: 34),
        Prescription(name: "Drug 6", count: 2)
    ]
    @AppStorage("lastDateString") var lastDateString: String = ""
    @Published var lastDate = Date()
    @Published var currentDate = Date()
    @Published var currentDateString = String()
    @Published var isANewDay = false
    @Published var plusButtonTapped = false

    func checkIfItsANewDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MM y"
        if lastDateString == String() {
            lastDateString = formatter.string(from: lastDate)
        }
        self.currentDate = Date()
        currentDateString = formatter.string(from: currentDate)

        if lastDateString != currentDateString {
            self.isANewDay = false
        }
    }
}
