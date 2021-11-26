//
//  HomeViewStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/15/21.
//

import Foundation

class HomeViewStateModel: ObservableObject {
    @Published var exampleArray = [
        Prescriptions(name: "Drug 1", count: 99),
        Prescriptions(name: "Drug 2", count: 10),
        Prescriptions(name: "Drug 3", count: 12),
        Prescriptions(name: "Drug 4", count: 56),
        Prescriptions(name: "Drug 5", count: 34),
        Prescriptions(name: "Drug 6", count: 2)
    ]
    @Published private var lastDateString = UserDefaults.standard.string(forKey: "lastDateString") ?? String()
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
            UserDefaults.standard.set(self.lastDateString, forKey: "lastDateString")
        } //sets initial value for lastDateString for first time app ever launches
        
        self.currentDate = Date()
        currentDateString = formatter.string(from: currentDate)
        //sets currentDateString for every time app launches
        if lastDateString != currentDateString {
            self.isANewDay = false
        }
        
    }
}
