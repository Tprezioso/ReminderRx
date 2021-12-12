//
//  CoreDataManager.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/20/21.
//

import Foundation
import CoreData

class PersistenceController {
    
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Prescriptions(context: viewContext)
//            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Prescriptions")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
//    let persistentContainer = NSPersistentContainer(name: "Prescriptions")
//    static let shared = CoreDataManager()
//
//    init(inMemory: Bool = false) {
//                if inMemory {
//                    persistentContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
//
//                }
////        persistentContainer = NSPersistentContainer(name: "Prescription")
//        persistentContainer.loadPersistentStores { description, error in
//            if let error = error {
//                fatalError("Core Data Store Failed \(error.localizedDescription)")
//            }
//        }
//    }
    
//    func getAllPrescriptions() -> [Prescription] {
//        let fetchRequest: NSFetchRequest<Prescription> = Prescription.fetchRequest()
//        do {
//            return try persistentContainer.viewContext.fetch(fetchRequest)
//        } catch {
//            return []
//        }
//    }
//    
//    func savePrescription(name: String, count: Int64, refills: Int64, isOn: Bool) {
//        let rx = Prescription(context: persistentContainer.viewContext)
//        rx.id = UUID()
//        rx.name = name
//        rx.count = count
//        rx.refills = refills
//        rx.isOn = isOn
//        
//        do {
//            try persistentContainer.viewContext.save()
//        } catch {
//            print("Failed to save. Error: \(error)")
//        }
//    }
}
