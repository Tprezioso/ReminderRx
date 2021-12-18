//
//  HomeViewStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/15/21.
//

import SwiftUI

class HomeViewStateModel: ObservableObject {
    @AppStorage("lastDateString") var lastDateString: String = ""
    @Published var lastDate = Date()
    @Published var currentDate = Date()
    @Published var currentDateString = String()
    @Published var isANewDay = false
    @Published var plusButtonTapped = false

    func theDayHasChanged() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MM y"
        if lastDateString == String() {
            lastDateString = formatter.string(from: lastDate)
        }
        self.currentDate = Date()
        currentDateString = formatter.string(from: currentDate)

        if lastDateString != currentDateString {
            return true
        } else {
            return false
        }
    }
}
