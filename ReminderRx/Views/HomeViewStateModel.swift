//
//  HomeViewStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/15/21.
//

import Foundation

class HomeViewStateModel: ObservableObject {
    @Published var exampleArray = [
        Prescription(name: "Drug 1", count: 99),
        Prescription(name: "Drug 2", count: 10),
        Prescription(name: "Drug 3", count: 12),
        Prescription(name: "Drug 4", count: 56),
        Prescription(name: "Drug 5", count: 34),
        Prescription(name: "Drug 6", count: 2)
    ]
}
