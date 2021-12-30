//
//  HomeViewStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/15/21.
//

import SwiftUI

class HomeViewStateModel: ObservableObject {
    @Published var lastDateString = UserDefaults.standard.string(forKey: "lastDateString") ?? String()
    @Published var plusButtonTapped = false
    @Published var editButtonTapped = false
    @Environment(\.managedObjectContext) var moc

    func theDayHasChanged() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MM y"
        if lastDateString == String() {
            let lastDate = Date()
            lastDateString = formatter.string(from: lastDate)
            UserDefaults.standard.set(self.lastDateString, forKey: "lastDateString")
            UserDefaults.standard.synchronize()
        } else {
            self.lastDateString = UserDefaults.standard.string(forKey: "lastDateString")!
        }
        
        let currentDate = Date()
        let currentDateString = formatter.string(from: currentDate)

        if self.lastDateString != currentDateString {
            UserDefaults.standard.set(currentDateString, forKey: "lastDateString")
            UserDefaults.standard.synchronize()
            return true
        } else {
            return false
        }
    }
    
    func updatePrescription(_ prescription: Prescriptions) {
        var newCount = Int64()
        var wasTapped = false
        
        if !prescription.isOn {
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
