//
//  HomeViewStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/15/21.
//

import SwiftUI

class HomeViewStateModel: ObservableObject {
    @Published var lastDateString = UserDefaults.standard.string(forKey: "lastDateString") ?? String()
    @Published var lastDate = Date()
    @Published var currentDate = Date()
    @Published var currentDateString = String()
    @Published var isANewDay = false
    @Published var plusButtonTapped = false
    @Environment(\.managedObjectContext) var moc

    func theDayHasChanged() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MM y"
        if lastDateString == String() {
            lastDateString = formatter.string(from: lastDate)
            UserDefaults.standard.set(self.lastDateString, forKey: "lastDateString")
            UserDefaults.standard.synchronize()
        }
        self.currentDate = Date()
        currentDateString = formatter.string(from: currentDate)

        if lastDateString != currentDateString {
            UserDefaults.standard.set(self.lastDateString, forKey: "lastDateString")
            UserDefaults.standard.synchronize()

            return true
        } else {
            return false
        }
    }
    
    func updatePrescription(_ prescription: Prescriptions) {
        var newCount = Int64()
        var wasTapped = false
        
        if !theDayHasChanged() && !prescription.isOn {
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
        if theDayHasChanged() {
            for prescription in prescriptions {
                moc.performAndWait {
                    prescription.isOn = false
                    try? moc.save()
                }
            }
        }
    }
}
