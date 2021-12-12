//
//  CoreDataManager.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/20/21.
//

import Foundation
import CoreData

class CoreDataManager {
    let persistentContainer: NSPersistentContainer
    
    init() {
        persistentContainer = NSPersistentContainer(name: "PrescriptionDataModel")
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data Store Failed \(error.localizedDescription)")
            }
        }
    }
    
    func getPrescription() -> [Prescription] {
        let fetchRequest: NSFetchRequest<Prescription> = Prescription.fetchRequest()
        do {
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
    func savePrescription(name: String, count: Int64, refills: Int64, isOn: Bool) {
        let rx = Prescription(context: persistentContainer.viewContext)
        rx.name = name
        rx.count = count
        rx.refills = refills
        rx.isOn = isOn
        
        do {
            try persistentContainer.viewContext.save()
        } catch {
            print("Failed to save. Error: \(error)")
        }
    }
}
