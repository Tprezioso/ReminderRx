//
//  EditRxStateModel.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 3/5/22.
//

import SwiftUI
import Combine

class EditRxStateModel: ObservableObject {
    @Published var date = Date()
    @Published var id: UUID
    @Published var name = ""
    @Published var count = ""
    @Published var countTotal = ""
    @Published var refills = ""
    @Published var prescription: Prescriptions
    @Published var isNotificationOn: Bool
    @Published var isSaveDisabled = false
    
    init(prescription: Prescriptions) {
        self.prescription = prescription
        self.id = prescription.id ?? UUID()
        self.name = prescription.name ?? ""
        self.count = prescription.count ?? ""
        self.countTotal = prescription.countTotal ?? ""
        self.refills = prescription.refills ?? ""
        self.date = prescription.savedDate ?? Date()
        self.isNotificationOn = prescription.isNotificationOn
    }
    
    func savePrescription(_ prescription: Prescriptions) {
        prescription.name = name
        prescription.count = count
        prescription.countTotal = countTotal
        prescription.refills = refills
        prescription.savedDate = date
    }
    
    lazy var nameValidation: ValidationPublisher = {
        $name.nonEmptyValidator("Please enter a prescription name")
    }()
    
    lazy var countValidation: ValidationPublisher = {
        $count.nonEmptyValidator("Please enter the number of pills in your prescription")
    }()
    
    lazy var countTotalValidation: ValidationPublisher = {
        $countTotal.nonEmptyValidator("Please enter the total number of pills in your prescription")
    }()
    
    lazy var refillValidation: ValidationPublisher = {
        $refills.nonEmptyValidator("Please enter any refills")
    }()
    
    lazy var allValidation: ValidationPublisher = {
        Publishers.CombineLatest4(
            nameValidation,
            countValidation,
            countTotalValidation,
            refillValidation
        ).map { v1, v2, v3, v4 in
            return [v1, v2, v3, v4].allSatisfy { $0.isSuccess } ? .success : .failure(message: "")
        }.eraseToAnyPublisher()
    }()
}
